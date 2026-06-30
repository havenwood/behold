# Behold

Give Behold two values and it searches for Ruby method calls that turn the first into the second.

## Warning

*THIS IS UNSAFE, EXPERIMENTAL CODE.*

This gem runs arbitrary code and can be capriciously destructive. Be warned! A denylist blocks the most catastrophic methods (process control, `eval`, file removal), but it cannot be exhaustive. Passing a module such as `File`, `Kernel` or `FileUtils` as a value is especially dangerous, since the search then fuzzes its public methods.

## Installation

```sh
gem install behold
```

## Examples

```ruby
require 'behold'

Behold.call 5, 25
#=> [[:abs2], [:**, 2], [:pow, 2], [:*, 5], [:+, 20], [:lcm, 25]]

Behold.call 'hi', 'hi!'
#=> [[:+, "!"], [:<<, "!"], [:concat, "!"], [:append_as_bytes, "!"], [:<<, 33], [:concat, 33]]

Behold.call [1, 2, 3], '1,2,3'
#=> [[:*, ","], [:join, ","]]

Behold.call Object, 'Object'
#=> [[:inspect], [:to_s], [:name]]

Behold.call 1, 2
#=> [[:next], [:succ], [:<<, 1], [:+, 1], [:*, 2], [:lcm, 2]]

Behold.call 'BBQ', ['B', 'B', 'Q']
#=> [[:split, ""], [:chars], [:grapheme_clusters], [:rpartition, "B"], [:lines, "B"], [:split, //]]

puts Behold.code 'BBQ', ['B', 'B', 'Q']
#>> "BBQ".split("")
#>> "BBQ".chars
#>> "BBQ".grapheme_clusters
#>> "BBQ".rpartition("B")
#>> "BBQ".lines("B")
#>> "BBQ".split(//)
```

## Multiple Examples

Give extra `[from, to]` pairs and Behold keeps only transforms that satisfy every one, dropping coincidences a single example allows. It also derives arguments such as separators, substring replacements and numeric deltas from the pair, and synthesizes blocks for higher-order methods like `map` and `select`, so it can find calls beyond its fuzz list.

```ruby
Behold.call 'shannon', 'Shannon', ['ruby', 'Ruby']
#=> [[:capitalize], [:capitalize!]]

Behold.code [1, 2, 3], '1::2::3'
#=> ["[1, 2, 3].*(\"::\")", "[1, 2, 3].join(\"::\")"]

Behold.code 'foo bar', 'foo::bar'
#=> ["\"foo bar\".gsub(\" \", \"::\")", "\"foo bar\".sub(\" \", \"::\")"]

Behold.code [1, 2, 3], [1, 4, 9]
#=> ["[1, 2, 3].map { _1 ** 2 }", "[1, 2, 3].flat_map { _1 ** 2 }"]

Behold.code %w[a bb ccc], [1, 2, 3]
#=> ["[\"a\", \"bb\", \"ccc\"].map(&:length)", "[\"a\", \"bb\", \"ccc\"].map(&:size)"]
```

A `count:` keyword caps how many results come back (the default is 6) and `timeout:` overrides the search budget in seconds (the default is 3).

```ruby
Behold.call 5, 25, count: 3
Behold.call 1, 2, timeout: 1
```

## Command Line Examples

Both arguments are parsed as Ruby literals (numbers, strings, symbols, arrays, hashes, ranges, regexps) or constants.

```sh
behold 21 42
#>> 21.<<(1)
#>> 21.*(2)
#>> 21.lcm(2)
#>> 21.lcm(6)
#>> 21.>>(-1.0)
#>> 21.<<(1.0)

behold 42 "'42'"
#>> 42.inspect
#>> 42.to_s
#>> 42.inspect(10)
#>> 42.to_s(10)
#>> 42.inspect(10)
#>> 42.to_s(10)
```
