[
  # NOTE: This code doesn't pass dialyxir because of the opaque types of erlavro functions.
  #       The fix of dialyxir requires to silence too much functions and that's sad.
  #       https://github.com/klarna/erlavro/blob/3dcb4a90af88bfe297ca60781265fbba025db48d/src/avro_binary_encoder.erl#L87-L88
  {":0:unknown_function Function ExUnit.Callbacks.on_exit/1 does not exist."},
  {"lib/avrora/encoder.ex", :call_without_opaque},
  {"lib/avrora/encoder.ex", :pattern_match, 118},
  {"lib/avrora/encoder.ex", :unused_fun, 185},
  {"lib/avrora/encoder.ex", :unused_fun, 191}
]
