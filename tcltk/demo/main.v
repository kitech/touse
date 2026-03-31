
 


#flag  -I/opu/tcltk9/include/
#flag  -L/opu/tcltk9/lib -Wl,-rpath=/opu/tcltk9/lib
#flag  -ltcl9tk9.0
#flag  -ltcl9.0
#flag  -lX11

#flag @VMODROOT/tcltk/demo/main.o

fn C.tkmain_exp()

fn main() {
	
	C.tkmain_exp()
}