module recut

import io
import os
import v.token

import vcp

// high level api

@[params]
pub struct InsertOption {
    pub mut:
}
@[params]
pub struct QueryOption {
    pub mut:
}
@[params]
pub struct SearchOption {
    pub mut:
    a int
    b string
    c f32
}

@[markused]
fn infer_some() {
    Record.ofstruct(SearchOption{})
    Record.ofmap(map[string]int{})
    Record.ofmap(map[string]string{})
}

pub fn Record.ofmap[T](o map[string]T) Record {
    r := Record.new()
    for k, v in o {
        s := ''
        $if T is $string { s = v }
        $else { s = v.str() }
    
        fld := Field.new(k, s)
        r.mset().append(.field, fld.vptr())
    }
    return r
}
pub fn (rec Record) tomap() map[string]string  {
    res := map[string]string{}
    
    return res 
}

// use struct field attrs
pub fn Record.ofstruct[T](o T) Record {
    r := Record.new()
    $for stfield in T.fields {
        name := stfield.name
        s := match stfield.typ {
            string { o.$(stfield.name).str() }
            else { o.$(stfield.name).str() }
        }
        $if stfield.typ is $string {
            s = o.$(stfield.name)
        } $else {
            o.$(stfield.name).str()
        }
        
        fld := Field.new(name, s)
        r.mset().append(.field, fld.vptr())
    }
    
    return r
}
pub fn Record.tostruct[T](o T) T {
    
    return T{}
}

// set %unique => field name
pub fn (set Rset) set_desc(stdfld StdFieldType, value string) {
    drec := set.descriptor()
    fld := Field.new_std(stdfld, value)
    defer { fld.destroy() }
    if !drec.field_p(fld.name()) {    
    }
    drec.mset().append(.field, fld)
}
pub fn (set Rset) set_descs(descs map[StdFieldType]string) {
    for stdfld, value in descs {
        set.set_desc(stdfld, value)
    }
}
pub fn (set Rset) descs() map[string]string {
    res := map[string]string{}
    drec := set.descriptor()

    for i in 0..int(StdFieldType.sigular) {
        name := Field.std_name(StdFieldType(i))
        if !drec.field_p(name) { continue }
        nflds := drec.get_num_fields_by_name(name)
        assert nflds==1, 'desc record must only 1 field for one name'
        fld := drec.get_field_by_name(name, 0)
        res[name] = fld.value()
    }
    
    return res
}

pub fn (rec Record) dump() ! string {
    buf := charptr(0)
    size := usize(0)
    wrs := Writer.new_str(&buf, &size)
    
    wrs.write_record(rec) !
    wrs.destroy()
    // assert size >= 0

    return buf.tosfree(int(size))    
}

pub fn (set Rset) dump() ! string {
    buf := charptr(0)
    size := usize(0)
    wrs := Writer.new_str(&buf, &size)
    
    wrs.write_rset(set) !
    wrs.destroy()
    // assert size >= 0

    return buf.tosfree(int(size))    
}

pub fn (mset Mset) dumpx() string {
    iter := mset.iterator()
    iterp := &iter
    // dump(iter)
    res := "MSET (${mset.count(.any)}) {"
    res += ifelse(mset.count(.any)>1, "\n", "")
    for i := 0; ; i++ {
        retdata, retelem, bv := iterp.next(recut.MsetType(0))
        if !bv { break }
        match retelem.type() {
            .field {
                retfld := Field(retdata)
                if retfld.name()=="" { // wtt
                    res += "  >> $i, empty name/value???\n"
                    continue 
                }
                res += "  >> $i, ${retfld.name()} = ${retfld.value()}\n"
            }
            else{res += "  >> $i, unknown elem type: ${retelem.type()}, $retdata}\n"}
        }
    }
    iterp.free1()
    res += "} << MSET"
    return res
}


pub fn (db DB) dump() ! string {
    buf := charptr(0)
    size := usize(0)
    wrs := Writer.new_str(&buf, &size)
    
    wrs.write_db(db) !
    wrs.destroy()
    // assert size >= 0

    return buf.tosfree(int(size))    
}

pub fn (db DB) save(filename string) ! {
    fp := os.open_file(filename, "w+") !
    defer { fp.close() }
    cfile := struct_field_get(fp, "cfile", &C.FILE(nil))
    
    wrs := Writer.new(cfile)
    defer { wrs.destroy() }
    wrs.write_db(db) !
}

pub fn DB.from[T](src T) ! DB {
    match src {
        io.Reader {
            return DB.from_reader(src)
        }
        else{}
    }
    return DB(0)
}


pub fn DB.from_file(filename string) ! DB {    
    fp := os.open(filename) !
    defer { fp.close() }
    cfile := struct_field_get(fp, "cfile", &C.FILE(nil))
    
    prs := Parser.new(cfile, filename)
    db := prs.db() !
    return db
}
pub fn DB.from_string(s string) ! DB {
    prs := Parser.new_str(s, @FILE_LINE)
    db := prs.db() !
    return db
}
pub fn DB.from_reader(r io.Reader) ! DB {
    return DB(0)
}

// TODO
pub fn (db DB) upsert(recty string, rec Record, uniq_field_name string) ! {
    if uniq_field_name != "" {
        assert rec.field_p(uniq_field_name)
        fld := rec.get_field_by_name(uniq_field_name, 0)
        ure := '$uniq_field_name = "${fld.value()}"'
        usex := Sex.new(true).compile(ure) !
        defer { usex.destroy() }
        
        rset_slt := db.query(usex, typep:recty.str)
        defer { rset_slt.destroy() }
        recdupcnt := rset_slt.num_records()
        if recdupcnt > 0 {
        if !db.delete(recty, usex) {return errorws("db.delete fail, cnt $recdupcnt, $ure", 0)}
        }
    }
    db.insert(recty, rec) !
}

pub enum QueryOp {
    // eq = int(token.Kind.eq)
    eq = int(token.Kind.assign)
    ne = int(token.Kind.ne)
    gt = int(token.Kind.gt)
    lt = int(token.Kind.lt)
    ge = int(token.Kind.ge)
    le = int(token.Kind.le)
}

// type=all
pub fn (db DB) query_field(name string, op QueryOp, value string) !Rset {
    return 0
}

// list types/tables
// ['default', ...]
pub fn (db DB) list_types() []string {
    res := []string{}
    for pos in 0..db.size() {
        rset := db.get_rset(pos)
        typ := rset.type()
        res << typ
    }
    return res
}

// name = 'value'
pub fn (db DB) delete_by_expr(typ string, expr string) ! {
    re := Sex.new(true).compile(expr) !
    defer { re.destroy() }
    
    db.delete(typ, re)
}

// name is column name/normal field name
// (.unique, 'url')
// (.key, 'username')
pub fn Field.new_std(fldty StdFieldType, name string) Field {
    stdname := Field.std_name(fldty)
    return Field.new(stdname, name)
}
