defmodule Blurhash do
  @moduledoc """
  Documentation for `Blurhash`.
  """

  use Bitwise

  defstruct [:average_colour, :components_x, :components_y, :pixels]

  base83_alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~'

  for {encoded, value} <- Enum.with_index(base83_alphabet) do
    defp encode_base_83_char(<<unquote(value)>>) do
      unquote(encoded)
    end

    defp decode_base_83_char(unquote(encoded)) do
      unquote(value)
    end
  end

  defp decode_base_83_number(digits, number_length, acc \\ 0)

  defp decode_base_83_number(rest, 0, acc), do: {:ok, acc, rest}

  defp decode_base_83_number([], _, _), do: {:error, :end_of_list}

  defp decode_base_83_number([digit | digits], number_length, acc) do
    decode_base_83_number(digits, number_length - 1, acc * 83 + digit)
  end

  defp srgb_to_linear(srgb_value) do
    value = srgb_value / 255

    if value <= 0.04045,
      do: value / 12.92,
      else: :math.pow((value + 0.055) / 1.055, 2.4)
  end

  defp linear_to_srgb(linear_value) do
    linear_value =
      cond do
        linear_value > 1 ->
          IO.inspect(linear_value, label: "over")
          1

        linear_value < 0 ->
          0

        true ->
          linear_value
      end

    if linear_value <= 0.0031308,
      do: round(linear_value * 12.92 * 255 + 0.5),
      else: round((1.055 * :math.pow(linear_value, 1 / 2.4) - 0.055) * 255 + 0.5)
  end

  defp sign_pow(value, exponent) do
    sign =
      if value < 0,
        do: -1,
        else: 1

    sign * :math.pow(value, exponent)
  end

  defp unquantize_colour(quantized_colour, max_ac), do: sign_pow((quantized_colour - 9) / 9, 2) * max_ac

  defp decode_ac_values(digits, max_ac, components_x, components_y) do
    size = components_x * components_y - 1

    try do
      {ac_values, rest} =
        Enum.map_reduce(1..size, digits, fn index, remaining_digits ->
          case decode_base_83_number(remaining_digits, 2) do
            {:ok, value, remaining_digits} ->
              # add matrix position with the color since we will need it for
              # inverse dct later
              matrix_pos = {rem(index, components_x), floor(index / components_x )}
              quantized_red = floor(value / (19 * 19))
              quantized_green = floor(rem(floor(value / 19), 19))
              quantized_blue = rem(value, 19)

              {{matrix_pos, unquantize_colour(quantized_red, max_ac),
                unquantize_colour(quantized_green, max_ac),
                unquantize_colour(quantized_blue, max_ac)}, remaining_digits}

            # Haven't found a more elegant solution to throwing in this case
            error ->
              throw(error)
          end
        end)

      if rest != [] do
        {:error, :unexpected_components}
      else
        {:ok, ac_values}
      end
    catch
      error -> error
    end
  end

  def decode(blurhash, width \\ 32, height \\ 32, punch \\ 1) do
    blurhash_digits =
      for <<c <- blurhash>> do
        decode_base_83_char(c)
      end

    with {:ok, sizeFlag, rest} <- decode_base_83_number(blurhash_digits, 1),
         components_y = floor(sizeFlag / 9) + 1,
         components_x = rem(sizeFlag, 9) + 1,
         {:ok, quantized_max_ac, rest} <- decode_base_83_number(rest, 1),
         max_ac = (quantized_max_ac + 1) / 166,
         {:ok, raw_average_colour, rest} <- decode_base_83_number(rest, 4),
         average_colour =
           {red, green, blue} =
           {bsr(raw_average_colour, 16), band(bsr(raw_average_colour, 8), 255),
            band(raw_average_colour, 255)},
         dc_value = {{0, 0}, srgb_to_linear(red), srgb_to_linear(green), srgb_to_linear(blue)},
         {:ok, ac_values} <- decode_ac_values(rest, max_ac, components_x, components_y),
         dct = [dc_value | ac_values] do
      # This seems really inefficient, but other implementations do the same thing.
      pixels =
        for y <- 0..(width - 1),
            x <- 0..(height - 1) do
          {red, green, blue} =
            Enum.reduce(dct, {0, 0, 0}, fn {{dct_x, dct_y}, current_red, current_green,
                                            current_blue},
                                           {red, green, blue} ->
              idct_basis =
                :math.cos(:math.pi() * x * dct_x / width) *
                  :math.cos(:math.pi() * y * dct_y / height)

              {red + current_red * idct_basis, green + current_green * idct_basis,
               blue + current_blue * idct_basis}
            end)

          {linear_to_srgb(red), linear_to_srgb(green), linear_to_srgb(blue)}
        end

      {:ok,
       %__MODULE__{
         average_colour: average_colour,
         components_x: components_x,
         components_y: components_y,
         pixels: pixels
       }}
    end
  end
end
