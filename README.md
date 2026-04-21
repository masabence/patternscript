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

There 3 types of quantifiers: `N of {}`, `N+ of {}` `N-M of {}`

Examples:

`2 of digit` => `\d{3}`

`3+ of wordchar` => `\w{3,}`

`4-5 of any` => `.{4,5}`


## Grouping

Curly braces are used to group elements, separated by commas. Trailing commas are allowed, but not required. Whitespace is ignored.

```
2 of digit,
" ",
3 of {
    digit,
    wordchar,
    " "
}
```

`\d{2} (?:\d\w ){3}`


## Character sets

You can write character sets using the `any from {}` and `any except {}` syntax.
The body can contain atoms like `digit` or character set literals like `[a-z]` or `[123]`.

Exammple:

```
any from {
    digit,
    [a-f],
    [A-F]
}
```

`[\da-fA-F]`


## Alternation

Use `or` between elements for alternation.

`"a" or "b"` => `a|b`


## Captures

The `capture` keyword is used to create capture groups. They can be named with the `<name>` syntax.

Capture groups can be referenced with the `ref` keyword followed by either `<name>` or an id.

```
capture  digit
capture <chars> 3 of any from [a-z]
ref 1
ref <chars>
```

`(\d)(<chars>)\1\k<chars>`

## Bindings

Bindings allow you to write reusable components using the `let name = {}` syntax.

```
let hex = any from {
    digit,
    [a-f],
    [A-F]
},

let block = {
    2 of hex,
    " "
},

4 of block,
2 of digit,

```

`(?:[\da-fA-F]{2} ){4}\d{2}`
