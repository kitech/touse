import mkuse.clang
import vcp.tcchf

ver := clang.get_clang_version()

println(ver)

tuidx := clang.create_index(0, 0)

println(tuidx)

tu, rc := clang.parse_translation_unit2(tuidx, "demo.c", ["-x", "c"], [], 0)

println("$tu $rc")

if tu != nil {
	n := clang.get_num_diagnostics(tu)
	println("diag num $n ")
}
