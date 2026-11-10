SECTIONS {
  .upic 0x60f5a500 : { *(.upic) }
  .hooki 0x610f5611 : { *(.hooki) }
}
ic_get  = 0x60f4afb5;
up_desc = 0x60f5a540;
