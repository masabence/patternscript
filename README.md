# Patternscript
Regex for humans


Patternscript is a readable DSL that compiles to regex. It doesn't make any decisions for you, it's a one to one mapping to real syntax, it's just way more readable.


## Atoms

| Keyword | Regex Equivalent |
| :--- | :--- |
| `digit` | `\d` |
| `wordchar` | `\w` |
| `whitespace` | `\s` |
| `boundary` | `\b` |
| `any` | `.` |
| `start` | `^` |
| `end` | `$` |

You can negate the first 4 with the `not` keyword.


## Strings

Use double quotes for automatic escaping.

`"..."` => `\.\.\.`

You can also use slashes to input raw regex.


## Quantifiers

`2 of digit` => `\d{3}`

`3+ of wordchar` => `\w{3,}`

`4-5 of any` => `.{4,5}`


## Character sets

## Grouping

## Alternation

## Captures

## Variables
