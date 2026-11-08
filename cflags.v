module clang

#flag -lclang
$if macos {
	#flag -L/opt/local/libexec/llvm-22/lib
	#flag -I/opt/local/libexec/llvm-22/include
}
