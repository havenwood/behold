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
#=> [[:+, "!"], [:<<, "!"], [:concat, "!"], [:append_as_bytes, "!"], [:<<, 33], [:concat, 33]]

Behold.call [1, 2, 3], '1,2,3'
#=> [[:*, ","], [:join, ","]]

Behold.call Object, 'Object'
#=> [[:inspect], [:to_s], [:name]]

Behold.call 1, 2
#=> [[:next], [:succ], [:<<, 1], [:+, 1], [:*, 2], [:lcm, 2]]

Behold.call 'BBQ', ['B', 'B', 'Q']
#=> [[:chars], [:grapheme_clusters], [:split, ""], [:rpartition, "B"], [:lines, "B"], [:split, //]]

puts Behold.code 'BBQ', ['B', 'B', 'Q']
#>> "BBQ".chars
#>> "BBQ".grapheme_clusters
#>> "BBQ".split("")
#>> "BBQ".rpartition("B")
#>> "BBQ".lines("B")
#>> "BBQ".split(//)
```

## Command Line Examples

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
