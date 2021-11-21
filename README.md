# Blurhash

A pure Elixir implementation [Blurhash](https://blurha.sh/) decoder/encoder.

Documentation: <https://hexdocs.pm/rinpatch_blurhash>

## Installation

Add Blurhash to your `mix.exs`:

```elixir
def deps do
  [
    {:blurhash, "~> 0.1.0", hex: :rinpatch_blurhash}
  ]
end
```

If you would like to use the `downscale_and_decode/3` function, you also need to add `Mogrify`:

```elixir
def deps do
  [
    {:blurhash, "~> 0.1.0", hex: :rinpatch_blurhash},
    {:mogrify, "~> 0.8.0"}
  ]
end
```

## Usage

### Encoding

The algorithm authors recommend to downscale the image to 32-20 pixels in width before encoding the blurhash, this will make encoding faster while leading to a similar-looking result. If ImageMagick is available on your system, you can simply add `Mogrify` package to your dependencies and use `downscale_and_encode/3`:
```elixir
path = "/tmp/lenna.png"
components_x = 4
components_y = 3

{:ok, blurhash} = Blurhash.downscale_and_encode(path, components_x, components_y)
```
**Be aware that this function uses a port and has no rate limiting or pooling. If a large number of blurhashes needs to be encoded at the same time, use an external solution to limit it, such as a job queue.**

If you already have a thumbnail to encode to a blurhash, the `encode/5` function accepts a raw 8-bit RGB binary along with it's width and height.

Here is how to convert an image to raw pixels using imagemagick:
```sh
convert lenna.png -depth 8 lenna.rgb
```

Then you can use it like this:
```elixir
lenna = File.read!("lenna.rgb")
width = 512
height = 512
components_x = 4
components_y = 3

{:ok, blurhash} = Blurhash.encode(lenna, width, height, 4, 3)
```

### Decoding

The `decode/3` functions accepts a blurhash, as well as the width and height of the result image. The output is 8-bit raw RGB binary and the average colour of the image as an `{r, g, b}` tuple.

For example, decoding a blurhash to a 32x32 image:
```elixir
blurhash = "LELxMqDQNE}@^5=aR6N^v}ozEh-n"
width = 32
height = 32

{:ok, pixels, {r, g, b} = average_color} = Blurhash.decode(blurhash, width, height)
```

`decode_to_iodata/3` function is the same as `decode/3`, except it returns iodata instead of a binary. This is useful if you are writing the raw pixels to a file or a socket later.

For example, decoding a blurhash, writing the raw pixels to a file and converting it to a jpg using `Mogrify`:
```elixir
blurhash = "LELxMqDQNE}@^5=aR6N^v}ozEh-n"
width = 32
height = 32

{:ok, pixels_iodata, {r, g, b} = average_color} = Blurhash.decode(blurhash, width, height)

decoded_raw_path = "lenna_blurhash.rgb"
File.write!(decoded_raw_path, pixels_iodata)

%{path: decoded_jpg_path} = 
  Mogrify.open(decoded_raw_path) |> Mogrify.custom("size", "#{width}x#{height}") |> Mogrify.custom("depth", "8")|> Mogrify.format("jpg") |> Mogrify.save()
```
