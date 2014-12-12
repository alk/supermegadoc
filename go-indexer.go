// NOTE: this file has parts of code of godoc which license can be
// seen here: http://golang.org/LICENSE
package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"go/ast"
	"go/build"
	"go/doc"
	"go/parser"
	"go/printer"
	"go/token"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
)

var output = bufio.NewWriter(os.Stdout)

func outputCDB(key, value string) {
	fmt.Fprintf(output, "+%d,%d:%s->%s\n", len(key), len(value), key, value)
}

func parseFile(fset *token.FileSet, filename string, mode parser.Mode) (*ast.File, error) {
	src, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	return parser.ParseFile(fset, filename, src, mode)
}

var errNoPackagesFound = errors.New("No packages found.")

func parseFiles(filenames []string) (pkg *ast.Package, first error) {
	if len(filenames) == 0 {
	}

	fset := token.NewFileSet()
	pkgs := make(map[string]*ast.Package)
	for _, filename := range filenames {
		file, err := parseFile(fset, filename, parser.ParseComments)
		if err != nil {
			if first == nil {
				first = err
			}
			continue
		}

		name := file.Name.Name
		var found bool
		pkg, found = pkgs[name]
		if !found {
			// TODO(gri) Use NewPackage here; reconsider ParseFiles API.
			pkg = &ast.Package{Name: name, Files: make(map[string]*ast.File)}
			pkgs[name] = pkg
		}
		pkg.Files[filename] = file
	}

	if first != nil {
		return nil, first
	}

	if l := len(pkgs); l != 1 {
		if l == 0 {
			return nil, errNoPackagesFound
		}

		keys := make([]string, 0, len(pkgs))

		for k := range pkgs {
			keys = append(keys, k)
		}

		return nil, fmt.Errorf("Multiple packages (%v) in same directory.", keys)
	}

	return pkg, nil
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

func mustPPNode(w io.Writer, node ast.Node) {
	err := printer.Fprint(w, token.NewFileSet(), node)
	if err != nil {
		log.Panic(err)
	}
}

func buildFuncKey(relpath string, f *doc.Func) string {
	var buf bytes.Buffer
	if f.Recv != "" {
		fmt.Fprintf(&buf, "%s/%s/%s ", relpath, f.Recv, f.Name)
	} else {
		fmt.Fprintf(&buf, "%s/%s ", relpath, f.Name)
	}

	decl := &ast.FuncDecl{Name: &ast.Ident{Name: ""}, Type: f.Decl.Type}
	mustPPNode(&buf, decl)

	return buf.String() + maybeDoc(f.Doc, f.Name)
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

func findValueSpec(v *doc.Value, name string) (*ast.ValueSpec, int) {
	for _, gspec := range v.Decl.Specs {
		s := gspec.(*ast.ValueSpec)
		for i, id := range s.Names {
			if id.Name == name {
				return s, i
			}
		}
	}
	return nil, 0
}

func ppValue(v *doc.Value, name string, def string) string {
	ovs, i := findValueSpec(v, name)
	if ovs == nil {
		return def
	}
	vs := &ast.ValueSpec{
		Names: []*ast.Ident{{Name: ""}},
		Type:  ovs.Type,
	}
	if ovs.Values != nil && i < len(ovs.Values) {
		vs.Values = []ast.Expr{ovs.Values[i]}
	} else if vs.Type == nil {
		return def
	}
	decl := &ast.GenDecl{
		Tok:   v.Decl.Tok,
		Specs: []ast.Spec{vs},
	}
	var buf bytes.Buffer
	mustPPNode(&buf, decl)

	// some values are initialized by huge multi-line expressions
	// (e.g. strings constants). We don't need them.
	if bytes.IndexByte(buf.Bytes(), '\n') >= 0 {
		buf.Reset()
		vs.Values = nil
		mustPPNode(&buf, decl)
	}

	return buf.String()
}

func outputValues(relpath string, values []*doc.Value, pk, def string) {
	for _, cn := range values {
		for _, name := range cn.Names {
			k := relpath + "/" + name + " " + ppValue(cn, name, def)
			if len(cn.Names) == 1 {
				k = k + maybeDoc(cn.Doc, name)
			}
			outputCDB(k, "godoc:"+relpath+pk)
		}
	}
}

func tryImport(root, relpath string) error {
	path := filepath.Join(root, relpath)
	ctx := build.Default
	dir, err := ctx.ImportDir(path, 0)
	if _, nogo := err.(*build.NoGoError); nogo {
		return nil
	}
	if err != nil {
		return fmt.Errorf("ImportDir failed: %v", err)
	}

	pkgFiles := append(dir.GoFiles, dir.CgoFiles...)
	fullPkgsFiles := make([]string, 0, len(pkgFiles))

	for _, p := range pkgFiles {
		fullPkgsFiles = append(fullPkgsFiles, filepath.Join(path, p))
	}

	pkg, err := parseFiles(fullPkgsFiles)
	if err != nil {
		if err == errNoPackagesFound {
			// that error is eaten silently
			return nil
		}
		return fmt.Errorf("Failed to parse pkg %s/%s: %v", root, relpath, err)
	}

	pdoc := doc.New(pkg, relpath, 0)

	outputValues(relpath, pdoc.Consts, "#pkg-constants", "const")
	outputValues(relpath, pdoc.Vars, "#pkg-variables", "var")

	for _, tp := range pdoc.Types {
		outputCDB(relpath+"/"+tp.Name+" "+ppType(tp)+maybeDoc(tp.Doc, tp.Name),
			"godoc:"+relpath+"#"+tp.Name)
		for _, fun := range tp.Methods {
			typename := fun.Recv
			if typename[0] == '*' {
				typename = typename[1:]
			}
			outputCDB(buildFuncKey(relpath, fun),
				"godoc:"+relpath+"#"+typename+"."+fun.Name)
		}
		for _, fun := range tp.Funcs {
			outputCDB(buildFuncKey(relpath, fun),
				"godoc:"+relpath+"#"+fun.Name)
		}
	}

	for _, fun := range pdoc.Funcs {
		outputCDB(buildFuncKey(relpath, fun),
			"godoc:"+relpath+"#"+fun.Name)
	}

	return nil
}

func walkDir(basepath string, pkgpath string) {
	// godoc excludes testdata too
	if filepath.Base(pkgpath) == "testdata" {
		return
	}

	path := filepath.Join(basepath, pkgpath)
	dirents, err := ioutil.ReadDir(path)
	if err != nil {
		log.Printf("Ignoring failure to ReadDir: %v", err)
	}

	err = tryImport(basepath, pkgpath)
	if err != nil {
		log.Printf("Ignoring import error: %v", err)
	}

	for _, info := range dirents {
		if !info.IsDir() {
			continue
		}
		name := info.Name()
		if name[0] == '_' || name[0] == '.' {
			continue
		}
		walkDir(basepath, filepath.Join(pkgpath, name))
	}
}

func main() {
	srcDirs := build.Default.SrcDirs()

	for _, d := range srcDirs {
		walkDir(d, "")
	}

	fmt.Fprintln(output)

	err := output.Flush()
	if err == nil {
		err = os.Stdout.Close()
	}
	if err != nil {
		log.Panic("Failed to close/flush: ", err)
	}
}
