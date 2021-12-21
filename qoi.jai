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
    px := Pixel.{ a = 255 };

    data := read_entire_file(filename);
    header := parse_header(*data);

    pixels : [..]Pixel;
    array_reserve(*pixels, header.width * header.height);

    while pixels.count < header.width * header.height
    {
        chunk_type := data[0];

        if chunk_type == QOI_OP_RGB {
            px.r = data[1];
            px.g = data[2];
            px.b = data[3];
            px.a = 255;
            advance(*data, 4);
            array_add(*pixels, px);
            index := (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) % 64;
            seen[index] = px;
        } 
        else if chunk_type == QOI_OP_RGBA {
            px.r = data[1];
            px.g = data[2];
            px.b = data[3];
            px.a = data[4];
            advance(*data, 5);
            array_add(*pixels, px);
            index := (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) % 64;
            seen[index] = px;
        } 
        else if chunk_type & 0b11000000 == QOI_OP_INDEX {
            index := data[0] & 0b00111111;
            advance(*data, 1);
            px = seen[index];
            array_add(*pixels, px);
        } 
        else if chunk_type & 0b11000000 == QOI_OP_DIFF {
            dr := cast(s8)(data[0] & 0b00110000) >> 4 - 2;
            dg := cast(s8)(data[0] & 0b00001100) >> 2 - 2;
            db := cast(s8)(data[0] & 0b00000011) >> 0 - 2;
            advance(*data, 1);
            px.r = cast(u8)((cast(s16)px.r + dr + 256) % 256);
            px.g = cast(u8)((cast(s16)px.g + dg + 256) % 256);
            px.b = cast(u8)((cast(s16)px.b + db + 256) % 256);
            array_add(*pixels, px);
            index := (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) % 64;
            seen[index] = px;
        } 
        else if chunk_type & 0b11000000 == QOI_OP_LUMA {
            dg := cast(s8)(data[0] & 0b00111111) - 32;
            dr := cast(s8)(data[1] & 0b11110000) >> 4 - 8;
            db := cast(s8)(data[1] & 0b00001111) >> 0 - 8;
            advance(*data, 2);
            px.g = cast(u8)((cast(s16)px.g + dg      + 256) % 256);
            px.r = cast(u8)((cast(s16)px.r + dg + dr + 256) % 256);
            px.b = cast(u8)((cast(s16)px.b + dg + db + 256) % 256);
            array_add(*pixels, px);
            index := (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) % 64;
            seen[index] = px;
        } 
        else if chunk_type & 0b11000000 == QOI_OP_RUN {
            length := data[0] & 0b00111111;
            for 0..length array_add(*pixels, px);
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