defmodule Blurhash do
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
  @spec decode(String.t(), pos_integer(), pos_integer()) ::
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
end
