# Behold

## Warning

*THIS IS UNSAFE, EXPERIMENTAL CODE.*

This gem runs arbitrary code and can be capriciously destructive. Be warned!

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
#=> [[:+, "!"], [:<<, "!"], [:concat, "!"], [:<<, 33], [:concat, 33], [:insert, 2, "!"]]

Behold.call [1, 2, 3], '1,2,3'
#=> [[:*, ","], [:join, ","]]

Behold.call Object, 'Object'
#=> [[:inspect], [:to_s], [:name], [:class_name], [:pretty_print_inspect]]

Behold.call 1, 2
#=> [[:next], [:succ], [:<<, 1], [:+, 1], [:lcm, 2], [:*, 2]]

Behold.call 'BBQ', ['B', 'B', 'Q']
#=> [[:grapheme_clusters], [:chars], [:split, ""], [:lines, "B"], [:rpartition, "B"], [:split, //]]

puts Behold.code 'BBQ', ['B', 'B', 'Q']
#>> "BBQ".grapheme_clusters
#>> "BBQ".chars
#>> "BBQ".split("")
#>> "BBQ".lines("B")
#>> "BBQ".rpartition("B")
#>> "BBQ".split(//)
```

## Command Line Examples

```sh
behold 21 42
#>> 21.<<(1)
#>> 21.lcm(2)
#>> 21.*(2)
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
