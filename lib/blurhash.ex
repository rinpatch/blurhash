defmodule Blurhash do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")

  @type blurhash :: String.t()
  @type pixels :: <<_::8>>
  @type color :: {0..255, 0..255, 0..255}

  @doc "Decode a blurhash. Returns raw pixels (8bit RGB) and average color."
  @spec decode(blurhash, pos_integer(), pos_integer()) ::
          {:ok, pixels(), color()} | {:error, :unexpected_components | :unexpected_end}
  def decode(blurhash, width, height) do
    with {:ok, pixels_iodata, average_color} <- Blurhash.Decoder.decode(blurhash, width, height) do
      {:ok, IO.iodata_to_binary(pixels_iodata), average_color}
    end
  end

  @type pixels_iodata :: pixels | [pixels | pixels_iodata]

  @doc "Same as `decode/3`, except returns pixels as iodata."
  @spec decode_to_iodata(String.t(), pos_integer(), pos_integer()) ::
          {:ok, pixels_iodata(), color()} | {:error, :unexpected_components | :unexpected_end}
  def decode_to_iodata(blurhash, width, height) do
    Blurhash.Decoder.decode(blurhash, width, height)
  end

  @doc "Encodes a blurhash from raw pixels (8bit RGB)."
  @spec encode(pixels(), pos_integer(), pos_integer(), 1..9, 1..9) ::
          {:ok, blurhash()}
          | {:error, :too_many_components | :too_little_components | :malformed_pixels}
  def encode(pixels, width, height, components_x, components_y) do
    Blurhash.Encoder.encode(pixels, width, height, components_x, components_y)
  end

  @doc "Downscale the image to 32 pixels wide and convert it to raw pixels, making it ready for Blurhash encoding. Returns path to image, width and height in case of success. Requires `Mogrify` package and ImageMagick to be installed on the system.`"
  @spec downscale_image(Path.t()) ::
          {:ok, Path.t(), pos_integer(), pos_integer()} | {:error, any()}
  def downscale_image(path) do
    try do
      # XXX: Convert to downscaled png first, so we can get width/height information,
      # since we are retaining aspect ratio

      %{path: resized_path, width: resized_width, height: resized_height} =
        path
        |> Mogrify.open()
        |> Mogrify.custom("thumbnail", "32x")
        |> Mogrify.format("png")
        |> Mogrify.save()
        |> Mogrify.verbose()

      %{path: converted_path} =
        resized_path
        |> Mogrify.open()
        |> Mogrify.format("rgb")
        |> Mogrify.custom("depth", "8")
        |> Mogrify.save()

      File.rm!(resized_path)
      {:ok, converted_path, resized_width, resized_height}
    rescue
      e -> {:error, e}
    end
  end

  @doc "Downscale the image using `&downscale_image/1` and encode a blurhash for it."
  @spec downscale_and_encode(Path.t(), pos_integer(), pos_integer()) ::
          {:ok, blurhash()} | {:error, any()}
  def downscale_and_encode(path, components_x, components_y) do
    with {:ok, path, width, height} <- downscale_image(path),
         {:ok, pixels} <- File.read(path) do
      try do
        encode(pixels, width, height, components_x, components_y)
      rescue
        e ->
          reraise e, __STACKTRACE__
      after
        File.rm!(path)
      end
    end
  end
end
