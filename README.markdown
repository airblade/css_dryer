# CssDryer -- Eliminate Repetition In Your Stylesheets

*Please note I am no longer working on this.  I'm pleased to say it was the first and, for a long time, the only Rails plugin to support nested selectors.  It did the job admirably but now I use [SASS](http://sass-lang.com/) instead.*


## Introduction

Cascading style sheets (CSS) are wonderful but repetitive.  [Repetition is bad](http://en.wikipedia.org/wiki/Don't_repeat_yourself), so CssDryer lets you write CSS without repeating yourself.  And you don't need to learn any new syntax.

There are two sources of repetition in CSS:

* nested selectors
* lack of variables

Nested selectors lead to CSS like this:

    div           { font-family: Verdana; }
    div#content   { background-color: green; }
    div#content p { color: red; }

Note the triple repetition of `div` and the double repetition of `#content`.

The lack of variables leads to CSS like this:

    .sidebar { border: 1px solid #fefefe; }
    .content { color: #fefefe; }

Note the repeated colour `#fefefe`.

CssDryer eliminates both of these.  The examples above become:

    <% dark_grey = '#fefefe' %>

    div {
      font-family: Verdana;
      #content {
        background-color: green;
        p { color: red; }
      }
    }

    .sidebar { border: 1 px solid <%= dark_grey %>; }
    .content { color: <%= dark_grey %>; }

Note, though, that `@media` blocks are preserved.  For example:

    @media screen, projection {
      div {font-size:100%;}
    }

is left unchanged.

The original whitespace is preserved as much as possible.


## Which Selectors Are Supported?

CssDryer handles all [CSS 2.1 selectors](http://www.w3.org/TR/CSS21/selector.html): nested descendant, child, adjacent, class, pseudo-class, attribute and id selectors.

Multiple comma separated selectors are also supported.


## Comments

Comments on nested selectors do not get 'flattened' or de-nested with their selector.  For example comment B will be left inside the html selector below:

Before:

    /* Comment A */
    html {
      /* Comment B */
      p {
        color: blue;
      }
    }

After:

    /* Comment A */
    html {
      /* Comment B */
    }
    html p {
      color: blue;
    }

This is suboptimal but I hope not too inconvenient.

Please also note that commas in comments will sometimes be replaced with a space.  This is due to a shameful hack in the code that handles comma-separated selectors.


## Partials

You may use partial nested stylesheets as you would with normal templates.  For example, assuming your controller(s) set the @user variable and a User has a background colour (red):

app/views/stylesheets/site.css.ncss:

    body {
      color: blue;
      <%= render :partial => 'content', :locals => {:background => @user.background} %>
    }

app/views/stylesheets/_content.css.ncss:

    div#content {
      background: <%= background %>;
      margin: 10px;
    }

And all this would render to `site.css`:

    body {
      color: blue;
    }
    body div#content {
      background: red;
      margin: 10px;
    }


## Remember the helper

Browser hacks are an ugly necessity in any non-trivial stylesheet.  They clutter up your stylesheet without actually adding anything.  They make you sad.

So encapsulate them in the StylesheetsHelper instead.  Separate your lovely CSS from the decidely unlovely hacks.  For example:

app/views/stylesheets/site.css.ncss:

    <% ie7 do %>
      #sidebar {
        padding: 4px;
      }
    <% end %>

This renders to `site.css`:

    *+html #sidebar {
      padding: 4px;
    }

In this example the hacky selector, `*+html`, isn't too bad.  However some hacks are pretty long-winded, and soon you'll thank yourself for moving them out of your nested stylesheet.

You don't have to limit yourself to browser hacks.  Consider self-clearing: to make an element clear itself requires 13 lines of CSS, in 3 selector blocks, by my count.  To make a second element clear itself, you need to add the element's selector to each of those three blocks.  It's fiddly.  And your stylesheet gets harder and harder to understand.

We can do better:

app/views/stylesheets/site.css.ncss:

    <%= self_clear 'div.foo', 'div.bar', 'baz' %>

Self-clear as many elements as you like in one easy line.


## Installation

### Rails plugin

Pre-requisite: Rails 2.3.

First, install in the usual Rails way.  From your application's directory:

    $ script/plugin install git://github.com/airblade/css_dryer.git

Second, generate the stylesheets controller and helper, and a test nested stylesheet:

    $ script/generate css_dryer

Third, add a named route to your `config/routes.rb`:

    map.stylesheets 'stylesheets/:action.:format', :controller => 'stylesheets'

Verify that everything is working by visiting this URL:

    http://0.0.0.0:3000/stylesheets/test.css

You should see this output:

    body {
      color: blue;
    }
    body p {
      color: red;
    }
    h4 {
      color: red;
    }
    h4 em { font-weight: bold; }
    * + html h2 {
      margin-top: 1em;
    }

If the output looks good, delete `app/views/stylesheets/{test,_foo}.css.ncss`.

### Rack

See the example `config.ru` file.  I'm a beginner with Rack so feedback would be much appreciated.
    

## Usage

You put your stylesheets, DRY or otherwise, in `app/views/stylesheets/`.  Once rendered they will be cached in `public/stylesheets/`.

DRY stylesheet files should have a `ncss` extension -- think 'n' for nested.  For example, `site.css.ncss`.

Get them in your views with a `css` extension like this:

    <link href='/stylesheets/site.css' rel='Stylesheet' type='text/css'>

or with Rails' `stylesheet_link_tag` helper:

    <%= stylesheet_link_tag 'site' %>


## Caching, Rake and Capistrano

By default the CSS rendered from your nested stylesheets is page-cached by Rails when caching is on (in production).  However there are two disadvantages:

* You can't bundle these stylesheets into a single file (`stylesheet_link_tag :all, :cache => true`).
* Rails' `stylesheet_link_tag` helper won't append a timestamp to the CSS path.  This means you cannot invalidate any browsers' caches of your stylesheet.  If you update your stylesheet, client web browsers will not see the update until they hard-reset their cache.

We can solve both these problems by pre-generating our CSS files from our nested stylesheets every time we deploy.  Rails will then just see normal CSS files and the bundling and cache-busting behaviour will work again.

The rake task `css_dryer:to_css` will convert your nested stylesheets into CSS files.  Use the following Capistrano code to get your servers to do this on each deploy:

    namespace :deploy do
      task :after_update_code do
        generate_css
      end

      task :generate_css, :roles => [:web] do
        run "cd #{release_path}; RAILS_ROOT=#{release_path} rake css_dryer:to_css"
      end
    end

Note: this bypasses Rails so you can't do it if your nested stylesheets use instance variables from your controller.


## Alternatives

* [Less CSS][less]: on top of the variables and nested rules that css_dryer offers, Less provides mixins and operations.  This is a popular project under active development.

* [Sass][sass]: variables, nested rules, mixins and more, all using a pared-down syntax.  From the creators of HAML.


## Credits

The idea came from John Nunemaker on [Rails Tips][railstips].  John beta-tested the code, provided a test case for @media blocks and suggested the controller's body.  Thanks John!


## To Do

* Configuration, e.g. `#implicit_nested_divs = true`
* Package as a gem as well as a plugin.
* Replace regexp-based nested-stylesheet parser with a Treetop parser.


## Author

[Andrew Stewart][aws], [AirBlade Software Ltd][airblade].


## Licence

CssDryer is available under the MIT licence.  See MIT-LICENCE for the details.

Copyright (c) 2006-2010 Andrew Stewart


  [less]: http://lesscss.org
  [sass]: http://sass-lang.com
  [railstips]: http://railstips.org/2006/12/7/styleaby-css-plugin/
  [aws]: mailto:boss@airbladesoftware.com
  [airblade]: http://airbladesoftware.com
