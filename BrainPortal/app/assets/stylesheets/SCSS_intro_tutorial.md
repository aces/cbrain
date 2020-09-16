# SCSS

A superset of css.

You can view the NeuroHUB styleguide live at `/styleguide`

## Topics

- [Variables](#variables)
- [@media](#media)
- [@function](#function)
- [@mixin / @include](#mixin)
- [@extend](#extend)
- [@syntax](#syntax)

## Variables

> `$VARIABLE:`

- They are preceeded by a `$` and preceeds the value with `:`.
- The convention is to make the name all in caps and stick to underscores if needed.
- The beauty of this is that if you need to change it once you can do so and affect everything (for better or for worse)
- Example:

  ```
  <!-- number -->
  $MAX_NUMBER: 38;

  <!-- string -->
  $BREAKPOINT_XS: 20em;

  <!-- array -->
  $list: 0rem, 0.25rem, 0.5rem, 0.75rem, 1rem, 1.25rem, 1.5rem, 2rem, 2.5rem,
  3rem, 4rem, 5rem, 6rem, 8rem;
  ```

- Note: scss does not make a distinction between `-` and `_`. Meaning $COLOR_BLUE and $COLOR-BLUE will not be differentiated.

## Media

> @media(property: value) { ... }

- Media queries are handled pretty similarly to css
- Example

  ```
  $BREAKPOINT_SM: 960px;

  @media (min-width: $BREAKPOINT_SM) {
    .class {
      display: none;
    }
  }
  ```

## Function

> @function name(<arguments...>){ @return }

- functions should only compute values and not have any side-effects.
- Example:

  ```
  @function sum($numbers...) {
    $sum: 0;
    @each $number in $numbers {
      $sum: $sum + $number;
    }
    @return $sum;
  }

  .micro {
    width: sum(50, 30, 100)px;
  }
  ```

## Mixin

> @mixin name(<arguments...>)

- Mixins allow you to define styles that can be re-used throughout your stylesheet.
- You can include these mixins into a context with `@include`.
- By setting a default value for a given argument, the argument becomes optional.
- Example:

  ```
  @mixin text($variant, $color:$DEFAULT_BLACK) {
    font-family: "system-ui", sans-serif;
    font-weight: 400;
    line-height: 1.5;
    -webkit-font-smoothing: auto;
    letter-spacing: 0;
    color: $color;

    @if $variant == "xxs" {
        font-size: 0.65rem;
    }
    @if $variant == "xs" {
        font-size: 0.75rem;
    }
    @if $variant == "sm" {
        font-size: 0.875rem;
    }
    @if $variant == "md" {
        font-size: 1rem;
    }
    @if $variant == "lg" {
        font-size: 1.25rem;
    }
    @if $variant == "xl" {
        font-size: 1.5rem;
    }
  }

  .header {
    @include text("lg")
  }

  <!-- COMPILED CSS -->
  .header{
    font-family: "system-ui", sans-serif;
    font-weight: 400;
    line-height: 1.5;
    -webkit-font-smoothing: auto;
    letter-spacing: 0;
    font-size: 1.25rem;
  }
  ```

## Extend

> @extend .className

- Should be used somewhat sparingly as can be error prone.
- Choose mixin over extend when you can
- Imports a class into another class.
- Example:

  - .btn-default is a class that styles a button in a basic way.
  - .btn-nav uses those base styles and either overwrites some and/or adds more styles.

  ```
    .btn-default{
      background: blue;
      color: white;
      width: 250px;
    }
    .btn-nav {
      @extend .btn-default;
      border-bottom: 2px solid pink;
    }
  ```

## Syntax

> .class { .nested-class {...} }

- SCSS indented syntax allows you to go one level deeper and write less.
- Example:

```
// in scss.
.page {
  .header{
    ...
  }
  .body{
    ...
  }
}

<!-- COMPILES TO -->
// in css
.page .header {...}
.page .body {...}

```

## General Neurohub Style Conventions

- Never set a px arbitrarily. If you absolutely must have something be a certain size or whatever, set it in a variable first.

  ```
  $MAX_WIDTH: 250px
  ```

- Along those lines... use the provided variables, i.e. if the color that you want doesn't exist in the palette, maybe it's for a reason.. If you really do need it, just add it to the palette and use that variable rather than using a hex code that no one will ever find and will just clutter the color-scape.

- To keep things from breaking, every page at the top has an id based on the route of the page `#nh_show_license`. Then I can safely nest my classes.

- Variables that are not global, I personally prefer to put them at the top of whatever section they're dealing with. So if `$NAV_BAR_WIDTH: 250px`, I would put that at the top of the nav bar section.

- In Neurohub, we have all our mixins set in sections that are not considered "pages". While there may be a case for a mixin to appear in a page section, up until now there hasn't been a need when we consider that by nature, mixins are to be repeated and therefore usually belong in sections that are re-used aka not individual pages.
