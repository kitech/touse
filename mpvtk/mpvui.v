module main

import os

import  vcp
import  vcp.tcltk

pub struct Uicomp {
	pub mut:
	btns []tcltk.Button
	icotray tcltk.Systray

	lo0 tcltk.Labelframe // vertical
	tlblo tcltk.Labelframe // horinize
	stblo tcltk.Labelframe // horinize
	vdofrm tcltk.Frame

	// right playlist
	lo1 tcltk.Labelframe // horinize
}

/*
  ---------- |||
  ---------- |||
  ---------- |||
*/


pub fn create_video_area() {
	frm := tcltk.Frame.new(gvars.lo0)
	// frm := tcltk.Frame.new(tcltk.Tkobject{})
	gvars.lo0.pack(frm, tcltk.PackOptions{side:"top", fill:"both", expend: 0})
	gv := gvars
	gv.vdofrm = frm

	wid := frm.id().clone()
	vcp.info("wid", wid, frm.name())
	gv.wid = wid 
}

pub fn create_video_area2() {
	// lb := tcltk.Labelframe.new("labeliss444", gvars.lo0)
	// lb.pack(lb, tcltk.PackOptions{side:"bottom"})

	// lb := tcltk.Labelframe.new("labeliss444", gvars.lo0)
	lb := tcltk.Labelframe.new("labeliss444", tcltk.Tkobject{})

	for i in 0..6 {
		btn := tcltk.Button.new("vvv btn${i}", lb)
		lb.pack(btn, tcltk.PackOptions{side:"right"})
		btn.connect(fn(cbval voidptr, args []string){
			vcp.info("hehhe", cbval, args.str())
			if gvars.mpvo == vnil {
				create_mpvobj(gvars.wid)
			}else{
				mpv_play_one('')
			}
		}, vnil)
	}

	gvars.lo0.pack(lb, tcltk.PackOptions{side:"bottom", fill:"x"})
}

pub fn create_winlo_begin() {
	gv := gvars

	if true {
	lb := tcltk.Labelframe.new("labeliss000", tcltk.Tkobject{})
	gv.lo0 = lb

	lb.pack(lb, tcltk.PackOptions{side:"left", fill:"y"})
	}

	if true {
	lb := tcltk.Labelframe.new("labeliss666", tcltk.Tkobject{})
	gv.lo1 = lb

	lb.pack(lb, tcltk.PackOptions{side:"right", fill:"y"})
	}

}
pub fn create_winlo_end() {
	gv := gvars

}

pub fn create_toolbar() {
	lb := tcltk.Labelframe.new("labeliss222", gvars.lo0)
	// lb := tcltk.Labelframe.new("labeliss222", tcltk.Tkobject{})

	for i in 0..6 {
		btn := tcltk.Button.new("test btn${i}", lb)
		lb.pack(btn, tcltk.PackOptions{side:"right"})
		btn.connect(fn(cbval voidptr, args []string){
			vcp.info("hehhe", cbval, args.str())
			if gvars.mpvo == vnil {
				// create_mpvobj(gvars.wid)
			}else{
				// mpv_play_one('')
			}
			play_file(os.args[1])
		}, vnil)
	}

	gvars.lo0.pack(lb, tcltk.PackOptions{side:"top", fill:"x"})
}

pub fn create_bottom_bar() {
	lb := tcltk.Labelframe.new("labeliss333", gvars.lo0)
	// lb := tcltk.Labelframe.new("labeliss333", tcltk.Tkobject{})
	for i in 0..6 {
		btn := tcltk.Button.new("stbar btn${i}", lb)
		lb.pack(btn, tcltk.PackOptions{side:"right"})
		btn.connect(fn(cbval voidptr, args []string){
			vcp.info("hehhe", cbval, args.str())
			if gvars.mpvo == vnil {
				create_mpvobj(gvars.wid)
			}else{
				mpv_play_one('')
			}
		}, vnil)
	}

	gvars.lo0.pack(lb, tcltk.PackOptions{side: "bottom", fill:"x"})
}

pub fn create_playlist_view() {
	mut parent := gvars.lo1
	// parent = tcltk.Tkobject{}
	if true {
	lb := tcltk.Listbox.new(parent)
	gvars.lo0.pack(lb, tcltk.PackOptions{side: "top", fill:"y"})
	}
	if true {
		lb := tcltk.Labelframe.new("labeliss777", parent)
		// lb := tcltk.Labelframe.new("labeliss333", tcltk.Tkobject{})
		for i in 0..4 {
			btn := tcltk.Button.new("Opb${i}", lb)
			lb.pack(btn, tcltk.PackOptions{side:"right"})
			btn.connect(fn(cbval voidptr, args []string){
				vcp.info("hehhe", cbval, args.str())
				if gvars.mpvo == vnil {
					create_mpvobj(gvars.wid)
				}else{
					mpv_play_one('')
				}
			}, vnil)
		}

		gvars.lo0.pack(lb, tcltk.PackOptions{side: "bottom", fill:"x"})
	}
}

pub fn create_top_menus() {
	menu0 := tcltk.Menu.new(tcltk.MenuOptions{})
	tcltk.Dotwin.conf(menu0)

	menu1 := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
	menu0.add(menu1, tcltk.MenuOptions{cascade: true, label: "File", underline: 0})
	if true {
		menua := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
		menu1.add(menua, tcltk.MenuOptions{cascade: true, label: "Exit", underline: 0})
	}

	menu2 := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
	menu0.add(menu2, tcltk.MenuOptions{cascade: true, label: "Edit", underline: 0})

	menu3 := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
	menu0.add(menu3, tcltk.MenuOptions{cascade: true, label: "Play", underline: 0})
	if true {
		menua := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
		menu3.add(menua, tcltk.MenuOptions{cascade: true, label: "Start", underline: 0})
		menub := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
		menu3.add(menub, tcltk.MenuOptions{cascade: true, label: "Stop", underline: 0})
		menuc := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
		menu3.add(menuc, tcltk.MenuOptions{cascade: true, label: "Pause", underline: 0})
		menud := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
		menu3.add(menud, tcltk.MenuOptions{cascade: true, label: "Reload", underline: 0})
	}

	menu4 := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
	menu0.add(menu4, tcltk.MenuOptions{cascade: true, label: "Help", underline: 0})
	if true {
		menua := tcltk.Menu.new(tcltk.MenuOptions{tearoff: 0})
		menu4.add(menua, tcltk.MenuOptions{cascade: true, label: "About", underline: 0})
	}
}


fn create_systray() {
	st := tcltk.Systray.new("sty123")
	st.exists()

	tcltk.Sysnotify.send("heheh",  "notifyeddd")
}
