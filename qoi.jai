Header :: struct {
    magic: [4]u8; // magic bytes "qoif"
    width: u32;  #place width;  w:[4]u8; // image width in pixels (BE)
    height: u32; #place height; h:[4]u8; // image height in pixels (BE)
    channels: u8; // 3 = RGB, 4 = RGBA
    colorspace: u8; // 0 = sRGB with linear alpha
}                   // 1 = all channels linear

Pixel :: struct {
    r: u8;
    g: u8;
    b: u8;
    a: u8;
}

qoi_load :: (filename: string) {
    seen : [64]Pixel;
    prev := Pixel.{ a = 255 };

    data := read_entire_file(filename);

    header := parse_header(*data);
    print("\n\n%\n", header);

    pixels : [..]Pixel; // TODO: prealloc size based on header

    while pixels.count < header.width * header.height
    {
        chunk_type := data[0];

        if chunk_type == QOI_OP_RGB {
            next := Pixel.{ a = 255 };
            next.r = data[1];
            next.g = data[2];
            next.b = data[3];
            advance(*data, 4);
            array_add(*pixels, next);
            prev = next;
            index := (next.r * 3 + next.g * 5 + next.b * 7 + next.a * 11) % 64;
            seen[index] = next;
        } 
        else if chunk_type == QOI_OP_RGBA {
            assert(false);
        } 
        else if chunk_type & 0b11000000 == QOI_OP_INDEX {
            index := data[0] & 0b00111111;
            advance(*data, 1);
            next := seen[index];
            array_add(*pixels, next);
            prev = next;
        } 
        else if chunk_type & 0b11000000 == QOI_OP_DIFF {
            dr := cast(s8)(data[0] & 0b00110000) >> 4 - 2;
            dg := cast(s8)(data[0] & 0b00001100) >> 2 - 2;
            db := cast(s8)(data[0] & 0b00000011) >> 0 - 2;
            advance(*data, 1);
            next := prev;
            next.r = cast(u8)((cast(s16)next.r + dr + 256) % 256);
            next.g = cast(u8)((cast(s16)next.g + dg + 256) % 256);
            next.b = cast(u8)((cast(s16)next.b + db + 256) % 256);
            array_add(*pixels, next);
            prev = next;
            index := (next.r * 3 + next.g * 5 + next.b * 7 + next.a * 11) % 64;
            seen[index] = next;
        } 
        else if chunk_type & 0b11000000 == QOI_OP_LUMA {
            print("TODO: QOI_OP_LUMA - just adding black for now\n");
            next : Pixel;
            array_add(*pixels, next);
            prev = next;
            advance(*data, 2);
        } 
        else if chunk_type & 0b11000000 == QOI_OP_RUN {
            length := data[0] & 0b00111111;
            for 0..length array_add(*pixels, prev);
            advance(*data, 1);
        }
        else {
            print("unknown chunk type\n");
            print("%\n", data[0]);
            assert(false);
        }
    }

    // TODO check for 7 0x00 and 1 0x01 bytes

    sb : String_Builder;
    append(*sb, "P3\n");
    append(*sb, sprint("% %\n", header.width, header.height));
    append(*sb, "255\n");
    for pixels append(*sb, sprint("% % % ", it.r, it.g, it.b));
    write_entire_file("test.ppm", builder_to_string(*sb));
}

main :: () { qoi_load("testcard.qoi"); }

#scope_file;

QOI_OP_RGB   :: 0b11111110;
QOI_OP_RGBA  :: 0b11111111;
QOI_OP_INDEX :: 0b00000000;
QOI_OP_DIFF  :: 0b01000000;
QOI_OP_LUMA  :: 0b10000000;
QOI_OP_RUN   :: 0b11000000;

parse_header :: (stream: *string) -> Header {
    header: Header;
    header.magic[0] = stream.data[0];
    header.magic[1] = stream.data[1];
    header.magic[2] = stream.data[2];
    header.magic[3] = stream.data[3];
    advance(stream, 4);

    header.w[0] = stream.data[3];
    header.w[1] = stream.data[2];
    header.w[2] = stream.data[1];
    header.w[3] = stream.data[0];
    advance(stream, 4);

    header.h[0] = stream.data[3];
    header.h[1] = stream.data[2];
    header.h[2] = stream.data[1];
    header.h[3] = stream.data[0];
    advance(stream, 4);

    header.channels = stream.data[0];
    advance(stream, 1);

    header.colorspace = stream.data[0];
    advance(stream, 1);

    return header;
}

#import "File";
#import "Basic";
#import "Bit_Operations";