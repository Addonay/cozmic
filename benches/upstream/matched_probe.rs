use cosmic_text::{Attrs, Buffer, FontSystem, Metrics, Shaping, Wrap, fontdb, Family, FontFeatures, FeatureTag};
fn main() {
    let mut db = fontdb::Database::new();
    db.load_fonts_dir("../../tests/fonts");
    db.set_sans_serif_family("Inter");
    let mut fs = FontSystem::new_with_locale_and_db("en-US".to_owned(), db);
    let mut disabled = FontFeatures::new();
    disabled.disable(FeatureTag::KERNING);
    for features in [FontFeatures::new(), disabled] {
        let mut buffer = Buffer::new_empty(Metrics::new(20.0, 24.0));
        buffer.set_text("AVATAR", &Attrs::new().family(Family::Name("Inter")).font_features(features), Shaping::Advanced, None);
        buffer.shape_until_scroll(&mut fs, false);
        let width: f32 = buffer.layout_runs().flat_map(|r| r.glyphs.iter()).map(|g| g.w).sum();
        println!("FEATURE width={width}");
    }
    for (name,text) in [("small", "Hello, world!".to_owned()),("latin", "The quick brown fox jumps over the lazy dog. ".repeat(100)),("arabic", "مرحبا بالعالم ".repeat(100))] {
        let mut times = Vec::new();
        let mut glyphs=0;
        let mut checksum=0.0f32;
        for i in 0..105 {
            let mut b = Buffer::new_empty(Metrics::new(10.0,10.0));
            b.set_wrap(Wrap::Word);
            b.set_size(Some(80.0), None);
            b.set_text(&text, &Attrs::new().family(Family::Name("Inter")), Shaping::Advanced, None);
            let start=std::time::Instant::now();
            b.shape_until_scroll(&mut fs, false);
            glyphs=0; checksum=0.0;
            for r in b.layout_runs() { for g in r.glyphs { glyphs+=1; checksum+=g.w; } }
            let elapsed=start.elapsed().as_nanos();
            std::hint::black_box((glyphs,checksum));
            if i>=5 {times.push(elapsed);}
        }
        times.sort();
        println!("MATCHED {name} median_ns={} glyphs={glyphs} width_sum={checksum}",times[50]);
    }
}
