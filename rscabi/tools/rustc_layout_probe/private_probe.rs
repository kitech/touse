// Optional tier-2 probe: dumps rustc_abi layout internals for one type.
//
// Requires nightly rustc with the `rustc-dev` component. Not used by the
// default oracle; see README.md in this directory.
#![feature(rustc_private)]

extern crate rustc_abi;
extern crate rustc_driver;
extern crate rustc_hir;
extern crate rustc_interface;
extern crate rustc_middle;

use rustc_abi::{TagEncoding, VariantIdx};
use rustc_middle::ty::{self, TyCtxt};

fn dump_one(tcx: TyCtxt<'_>, def_id: rustc_hir::def_id::LocalDefId) {
    let ty = tcx.type_of(def_id).instantiate_identity();
    let layout = tcx.layout_of(ty::ParamEnv::reveal_all().and(ty));

    let Ok(layout) = layout else {
        println!("layout error for {:?}", ty);
        return;
    };

    let layout = layout.layout;
    println!("type: {:?}", ty);
    println!("size: {}", layout.size.bytes());
    println!("align: {}", layout.align.bytes());
    println!("fields_kind: {:?}", layout.fields);
    println!("backend: {:?}", layout.backend_repr);
    println!("largest_niche: {:?}", layout.largest_niche);

    match layout.variants {
        rustc_abi::Variants::Single { index } => {
            println!("variants: single {:?}", index);
        }
        rustc_abi::Variants::Multiple {
            tag,
            tag_encoding,
            tag_field,
            variants,
        } => {
            println!("variants: {}", variants.len());
            println!("tag_field: {:?}", tag_field);
            println!("tag: {:?}", tag);
            match tag_encoding {
                TagEncoding::Direct => println!("tag_encoding: direct"),
                TagEncoding::Niche {
                    dataful_variant,
                    niche_variants,
                    niche_start,
                } => {
                    println!("tag_encoding: niche");
                    println!("untagged_variant: {:?}", dataful_variant);
                    println!(
                        "niche_variants: {:?}..={:?}",
                        niche_variants.start(),
                        niche_variants.end()
                    );
                    println!("niche_start: {}", niche_start);
                }
            }
            for (index, variant) in variants.iter_enumerated() {
                println!("variant[{:?}]: size={} align={:?}", index, variant.size, variant.align.abi);
                println!("variant[{:?}].memory_index: {:?}", index, variant.fields);
                if let Some(range) = niche_range_for(tcx, layout, index) {
                    println!("variant[{:?}].tag_range: {:?}", index, range);
                }
            }
        }
    }
}

fn niche_range_for(
    _tcx: TyCtxt<'_>,
    _layout: &rustc_abi::LayoutData<rustc_abi::FieldIdx, VariantIdx>,
    _index: VariantIdx,
) -> Option<(u128, u128)> {
    // rustc does not store one tag range per variant as a public field;
    // derive it from `niche_start` plus the variant index when needed.
    None
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: private_probe <crate.rlib> [TYPE]");
        std::process::exit(2);
    }
    rustc_driver::RunCompiler::new(&args, &mut Callbacks).run();
}

struct Callbacks;

impl rustc_driver::Callbacks for Callbacks {
    fn after_analysis<'tcx>(
        &mut self,
        _compiler: &rustc_interface::interface::Compiler,
        tcx: TyCtxt<'tcx>,
    ) -> rustc_driver::Compilation {
        for id in tcx.hir_crate_items(()).definitions() {
            if let rustc_hir::def::DefKind::Struct
                | rustc_hir::def::DefKind::Enum
                | rustc_hir::def::DefKind::Union = tcx.def_kind(id)
            {
                dump_one(tcx, id);
            }
        }
        rustc_driver::Compilation::Stop
    }
}
