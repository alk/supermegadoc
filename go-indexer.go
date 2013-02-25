// NOTE: this file has parts of code of godoc which license can be
// seen here: http://golang.org/LICENSE
package main

import (
	"bufio"
	"fmt"
	"go/ast"
	"go/build"
	"go/doc"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"path/filepath"
)

var output *bufio.Writer

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

func parseFiles(fset *token.FileSet, filenames []string) (pkgs map[string]*ast.Package, first error) {
	pkgs = make(map[string]*ast.Package)
	for _, filename := range filenames {
		file, err := parseFile(fset, filename, parser.ParseComments)
		if err != nil {
			if first == nil {
				first = err
			}
			continue
		}

		name := file.Name.Name
		pkg, found := pkgs[name]
		if !found {
			// TODO(gri) Use NewPackage here; reconsider ParseFiles API.
			pkg = &ast.Package{Name: name, Files: make(map[string]*ast.File)}
			pkgs[name] = pkg
		}
		pkg.Files[filename] = file
	}
	return
}

func tryImport(root, relpath string) error {
	path := filepath.Join(root, relpath)
	ctx := build.Default
	dir, err := ctx.ImportDir(path, 0)
	if _, nogo := err.(*build.NoGoError); nogo {
		return nil
	}
	if err != nil {
		return err
	}

	pkgFiles := append(dir.GoFiles, dir.CgoFiles...)
	// fmt.Printf("path: %s pkgFiles: %v\n", path, pkgFiles)

	fullPkgsFiles := make([]string, 0, len(pkgFiles))

	for _, p := range pkgFiles {
		fullPkgsFiles = append(fullPkgsFiles, filepath.Join(path, p))
	}

	fset := token.NewFileSet()

	pkgs, err := parseFiles(fset, fullPkgsFiles)
	if err != nil {
		return err
	}

	if len(pkgs) != 1 {
		var keys []string = make([]string, 0, len(pkgs))

		for k, _ := range pkgs {
			keys = append(keys, k)
		}

		fmt.Printf("pkg keys: %v\n", keys)

		panic("multiple pkgs")
	}

	var pkg *ast.Package
	{
		for _, p := range pkgs {
			pkg = p
		}
	}

	if pkg == nil {
		panic("pkg = nil")
	}

	pdoc := doc.New(pkg, relpath, 0)

	for _, cn := range pdoc.Consts {
		for _, name := range cn.Names {
			outputCDB(relpath+"/"+name+"$const",
				"godoc:"+relpath+"#pkg-constants")
		}
	}

	for _, tp := range pdoc.Types {
		outputCDB(relpath+"/"+tp.Name+"$type",
			"godoc:"+relpath+"#"+tp.Name)
		for _, fun := range tp.Methods {
			name := fun.Recv + "/" + fun.Name
			typename := fun.Recv
			if typename[0] == '*' {
				typename = typename[1:len(typename)]
			}
			outputCDB(relpath+"/"+name+"$meth",
				"godoc:"+relpath+"#"+typename+"."+fun.Name)
		}
	}

	for _, vr := range pdoc.Vars {
		for _, name := range vr.Names {
			outputCDB(relpath+"/"+name+"$var",
				"godoc:"+relpath+"#pkg-variables")
		}
	}

	for _, fun := range pdoc.Funcs {
		name := fun.Name
		outputCDB(relpath+"/"+name+"$func",
			"godoc:"+relpath+"#"+name)
	}

	return nil
}

func WalkDir(basepath string, pkgpath string) error {
	path := filepath.Join(basepath, pkgpath)
	dirents, err := ioutil.ReadDir(path)
	if err != nil {
		return err
	}

	err = tryImport(basepath, pkgpath)
	if err != nil {
		return err
	}

	for _, info := range dirents {
		if !info.IsDir() {
			continue
		}
		name := info.Name()
		if name[0] == '_' || name[0] == '.' {
			continue
		}
		err = WalkDir(basepath, filepath.Join(pkgpath, name))
		if err != nil {
			return err
		}
	}

	return nil
}

func main() {
	output = bufio.NewWriter(os.Stdout)
	defer output.Flush()
	srcDirs := build.Default.SrcDirs()

	// fmt.Printf("srcdirs:\n%v\n", srcDirs)

	for _, d := range srcDirs {
		err := WalkDir(d, "")
		if err != nil {
			panic(err)
		}
	}

	fmt.Fprintf(output, "\n")
}
