module pftray

// need manual compile this .o
// cc -c tray_darwin.m
#flag @DIR/tray_darwin.o
#flag -framework Cocoa

#flag @DIR/example.o

fn C.main_ccc() int
pub fn main_demo() {
	C.main_ccc()
}

