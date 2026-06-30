# Behold

Give Behold two values and it searches for Ruby method calls that turn the first into the second.

## Warning

*THIS IS UNSAFE, EXPERIMENTAL CODE.* Behold runs arbitrary methods and can be capriciously destructive. A denylist blocks the most catastrophic ones (process control, `eval`, file removal), but it cannot be exhaustive. Passing a module like `File`, `Kernel` or `FileUtils` is especially dangerous, since the search then fuzzes its methods.

## Installation

```sh
gem install behold
```

## Examples

```ruby
require 'behold'

Behold.call 5, 25
#=> [abs2, **(2), pow(2), *(5), +(20), lcm(25)]

Behold.call 'hi', 'hi!'
#=> [+("!"), <<("!"), concat("!"), append_as_bytes("!"), <<(33), concat(33)]

Behold.call Object, 'Object'
#=> [inspect, to_s, name]

Behold.call 'BBQ', ['B', 'B', 'Q']
#=> [split(""), chars, grapheme_clusters, rpartition("B"), lines("B"), split(//)]
```

`Behold.code` renders the same matches as runnable source.

```ruby
puts Behold.code 'BBQ', ['B', 'B', 'Q'], count: 3
#>> "BBQ".split("")
#>> "BBQ".chars
#>> "BBQ".grapheme_clusters
```

## Response objects

Each match is a `Behold::Call` (or a `Behold::Chain` for a two-step result). It carries `meth`, `args`, `kwargs` and `block`, and can be applied or rendered against any receiver.

```ruby
match = Behold.call(5, 25).find { |call| call.meth == :* }
match.meth         #=> :*
match.args         #=> [5]
match.apply(5)     #=> 25
match.render('5')  #=> "5.*(5)"
```

## Refining with examples

Give extra `[from, to]` pairs and Behold keeps only transforms that satisfy every one, dropping coincidences a single example allows. It also derives arguments like separators, replacements and numeric deltas from the pair, synthesizes blocks for higher-order methods like `map`, and tries curated keyword arguments like `round(half: :up)`.

```ruby
Behold.call 'shannon', 'Shannon', ['ruby', 'Ruby']
#=> [capitalize, capitalize!]

Behold.code 'foo bar', 'foo::bar'
#=> ["\"foo bar\".gsub(\" \", \"::\")", "\"foo bar\".sub(\" \", \"::\")"]

Behold.code [1, 2, 3], [1, 4, 9]
#=> ["[1, 2, 3].map { _1 ** 2 }", "[1, 2, 3].flat_map { _1 ** 2 }", "[1, 2, 3].filter_map { _1 ** 2 }"]
```

## Two-step fallbacks

When no single call works, Behold falls back to a two-step chain. Direct calls always win, so a chain only appears when nothing simpler matches. The first step can coerce across types (`to_f`, `to_r`, `to_c`), so a stringified number can be parsed before arithmetic.

```ruby
Behold.code 'hello', 'OLLEH', ['world', 'DLROW'], count: 3
#=> ["\"hello\".reverse.upcase", "\"hello\".reverse.upcase!", "\"hello\".reverse.swapcase"]

Behold.code '1.5', 3.0
#=> ["\"1.5\".to_f.*(2)"]
```

`count:` caps how many results come back (default 6) and `timeout:` bounds the search in seconds (default 3).

```ruby
Behold.call 5, 25, count: 3
Behold.call 1, 2, timeout: 1
```

## Command line

Both arguments are parsed as Ruby literals (numbers, strings, symbols, arrays, hashes, ranges, regexps) or constants.

```sh
behold 42 "'42'"
#>> 42.inspect
#>> 42.to_s
#>> 42.inspect(10)
#>> 42.to_s(10)
```
