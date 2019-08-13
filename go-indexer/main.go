package main // import "github.com/alk/supermegadoc/go-indexer"

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"go/ast"
	"go/doc"
	"go/format"
	"go/token"
	"log"
	"os"
	"strings"

	"golang.org/x/tools/go/packages"
)

var useCDB = flag.Bool("use_cdb", true, "output in format for cdb tool")
var chdirTo = flag.String("chdir", "", "chdir to given directory (when not empty)")

var output = bufio.NewWriter(os.Stdout)

func outputCDB(key, value string) {
	if *useCDB {
		fmt.Fprintf(output, "+%d,%d:%s->%s\n", len(key), len(value), key, value)
	} else {
		fmt.Printf("%s -> %s\n", key, value)
	}
}

type docCollection struct {
	buf      bytes.Buffer
	pkg      string
	typeName string
}

func (dc *docCollection) setPkgName(pkg string) func() {
	dc.pkg = pkg
	return func() {
		dc.pkg = ""
	}
}

func (dc *docCollection) setTypeName(typeName string) func() {
	var old string
	old, dc.typeName = dc.typeName, typeName
	return func() {
		dc.typeName = old
	}
}

type nameDeclPair struct {
	name string
	decl *ast.GenDecl
}

func expandDecl(decl *ast.GenDecl, typeName string) []nameDeclPair {
	var ret []nameDeclPair
	for _, s := range decl.Specs {
		spec := s.(*ast.ValueSpec)
		for _, name := range spec.Names {
			newSpec := &ast.ValueSpec{
				Names: []*ast.Ident{name},
				Type:  spec.Type,
			}
			if newSpec.Type == nil && typeName != "" {
				newSpec.Type = ast.NewIdent(typeName)
			}
			cp := &ast.GenDecl{
				Tok:   decl.Tok,
				Specs: []ast.Spec{newSpec},
			}
			ret = append(ret, nameDeclPair{name.Name, cp})
		}
	}
	return ret
}

var emptyFset = token.NewFileSet()

func (dc *docCollection) addString(name, entry string) {
	k := dc.pkg
	v := dc.pkg
	if dc.pkg != "" {
		k += "/"
		v += "."
	}
	if dc.typeName != "" {
		k += dc.typeName + "."
		v += dc.typeName + "."
	}
	k += entry
	v += name

	outputCDB(k, v)
}

func maybeDoc(adoc string, name string) string {
	adoc = strings.TrimRight(doc.Synopsis(adoc), ".")
	if adoc == "" {
		return ""
	}
	prefix := name + " "
	if strings.HasPrefix(adoc, prefix) {
		adoc = adoc[len(prefix):]
	} else if ap := "A " + prefix; strings.HasPrefix(adoc, ap) {
		adoc = adoc[len(ap):]
	} else if ap := "An " + prefix; strings.HasPrefix(adoc, ap) {
		adoc = adoc[len(ap):]
	}
	return " - " + adoc
}

func (dc *docCollection) addNode(name string, node interface{}, doc string) {
	doc = maybeDoc(doc, name)

	dc.buf.Reset()
	format.Node(&dc.buf, emptyFset, node)
	dc.addString(name, name+" "+dc.buf.String()+doc)
}

func (dc *docCollection) addValues(values []*doc.Value, typeName string) {
	for _, cc := range values {
		for _, pair := range expandDecl(cc.Decl, typeName) {
			dc.addNode(pair.name, pair.decl, "")
		}
	}
}

func ppTypeExpr(e ast.Expr) string {
	switch st := e.(type) {
	case *ast.Ident:
		return st.Name
	case *ast.StarExpr:
		return "*" + ppTypeExpr(st.X)
	case *ast.InterfaceType:
		return "interface"
	case *ast.StructType:
		return "struct"
	}
	return ""
}

func ppType(t *doc.Type) string {
	if len(t.Decl.Specs) != 1 {
		return "type"
	}
	spec := t.Decl.Specs[0].(*ast.TypeSpec)
	rv := ppTypeExpr(spec.Type)
	if rv == "" {
		return "type"
	}
	return rv + " type"
}

func (dc *docCollection) addPkg(pkg *doc.Package) {
	defer dc.setPkgName(pkg.ImportPath)()

	dc.addValues(pkg.Consts, "")
	dc.addValues(pkg.Vars, "")

	for _, f := range pkg.Funcs {
		dc.addNode(f.Name, f.Decl, f.Doc)
	}
	for _, t := range pkg.Types {
		doc := maybeDoc(t.Doc, t.Name)
		dc.addString(t.Name, t.Name+" "+ppType(t)+doc)
		for _, f := range t.Funcs {
			dc.addNode(f.Name, f.Decl, f.Doc)
		}

		func() {
			defer dc.setTypeName(t.Name)()

			for _, m := range t.Methods {
				dc.addNode(m.Name, m.Decl, m.Doc)
			}
			dc.addValues(t.Consts, t.Name)
			dc.addValues(t.Vars, t.Name)
		}()
	}
}

func (dc *docCollection) addPkgByName(importPath string) error {
	cfg := &packages.Config{
		Mode: packages.LoadTypes | packages.NeedSyntax |
			packages.NeedTypesInfo,
	}
	pkgs, err := packages.Load(cfg, importPath)
	if err != nil {
		return err
	}

	for _, foundPkg := range pkgs {
		if len(foundPkg.Syntax) == 0 {
			// some builtin package?
			// log.Printf("missing source for %v", foundPkg.PkgPath)
			continue
		}
		apkg := &ast.Package{
			Name:  foundPkg.Syntax[0].Name.Name,
			Files: make(map[string]*ast.File),
		}
		for i, s := range foundPkg.Syntax {
			apkg.Files[foundPkg.CompiledGoFiles[i]] = s
		}
		pkg := doc.New(apkg, foundPkg.PkgPath, 0)
		dc.addPkg(pkg)
	}

	return nil
}

func main() {
	flag.Parse()
	if *chdirTo != "" {
		os.Chdir(*chdirTo)
	}

	var dc docCollection
	err := dc.addPkgByName("all")
	if err != nil {
		log.Fatalf("bad list: %v", err)
	}

	fmt.Fprintln(output)
	output.Flush()
}
