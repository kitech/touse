module recut

import io
import os

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
}

pub fn Record.ofmap[T](o map[string]T) Record {
    r := Record.new()
    for k, v in o {
        s := match v {
            string { v }
            else { '$v' }
        }
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
        s := o.$(stfield.name).str()
        s = match stfield.typ {
                string { }
                else { }
        }
        
        fld := Field.new(name, s)
        r.mset().append(.field, fld.vptr())
    }
    
    return r
}
pub fn Record.tostruct[T](o T) T {
    
    return T{}
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
pub fn (db DB) upsert() ! {
    
}
