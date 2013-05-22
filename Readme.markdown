# The Legacy HubSpot Static Daemon

This is the front-end server, dependency manager, and build tools used by HubSpot internally. 

To learn more about it, please read this posts:

 - [HubSpot front-end development at scale](http://dev.hubspot.com/blog/frontend-development-at-scale-1)
 - [HubSpot front-end development at scale part 2](http://dev.hubspot.com/blog/front-end-development-2)
  
  __Todo, reference the other http://dev.hubspot.com/blog posts that are on their way...__

_Note: in the current state, this code is quite specific to HubSpot's internals (and a bit of a mess). We are working on a much cleaner and extendable v2 called Asset Bender. That code is in-progress on the [future branch](https://github.com/HubSpot/asset_bender/tree/future)_.

## Installing

1. Clone me!
2. Install the latest version of ruby (1.9.3 as of right now). On a mac you can do that with `brew install ruby` or [rbenv](https://github.com/sstephenson/rbenv/). On linux, it is probably a simple apt-get or yum install away. And on windows, you'll probably have to download something or using that ick-y Cygwin mess :).
  - Note, you can get away with using 1.8.7 if you really need to, but it is _far_ slower. Like 50-100% slower in some cases. So it is worth it to install 1.9.3 now to save you time later.
3. See if ruby gems have been installed by trying to run `gem list` (make sure that the ruby you just installed is on your path). If it isn't there, go out there and [get it](http://rubygems.org/pages/download).
4. Install bundler with `gem install bundler`.
5. CD into the directory where you cloned this repo and run `bundle install` to install all the other necessary dependencies. (If you have trouble try `bundle install --without development`)
6. Stay in that directory and give it a whirl with `./hs-static run`.

Common problems:

1. If you see `cross-thread violation on rb_gc()`, you may need to remove your ~/.gemrc file or remove any GEMPATH configuration in zshell et. all.

## Configuring

If you haven't already, run the daemon with `./hs-static run` and kill it with ctrl-c. Assuming that was the first time you ran it, you should see a message telling you that it created new config file in your home directory: ~/.hubspot/config.yaml. Open that file up in your favorite text editor.

For now, the only part of the config file that you should care about is the list of `static_projects`. That represents all of the projects that you want to serve static files from (local on your filesystem). So you'll want to include the projects that you are currently working on and editing (for now, let's just stick with one project):

    # A list of all the current static projects you are working on
    static_projects:
      - ~/dev/src/example_web

    # Port for the static daemon to run on (3333 by default)
    # port: 3333

If you want to run this static server on a different port, uncomment the "port:" line and set your desired port.

You can override (most) of the settings in `~/.hubspot/conf.yaml` by passing paramaters to `hs-static`. See `hs-static help` for more details. 

## How does it work?

The above configuration will automatically serve all the files contained withing the `static/` folder inside each of the projects specififed. But note, you must have at least one "asset" folder instead of `static/`, such as `js/`, `sass/`, `img/`, etc. Otherwise, it won't work.

Here is the recommended convention (these are the droids you are looking for):

    project_name/
        static/
            static_conf.json  -> Defines the other static projects this project depends on (more later)

            js/       ->  All regular javascript files
            coffee/   ->  All Coffeescript files
            css/      ->  All regular css files
            sass/     ->  All SASS (white-space signficance rules!) files
            img/      ->  All your images
            ...       ->  Any other static folders you might need (fonts, documents, etc)
        ...           ->  All of your other project folders (could be django/java stuff 'er whatever)

Note: you don't absolutely have to put all js files inside `js/` and all css files inside `css/`. It is ok if you drop them in your `coffee/` and `sass/` folders. In fact, if you just have a couple small js/css files and most of your code is in CoffeeScript or SASS, then it is probably better to forgo the `js/` and `css/` folders entirely. The static daemon has your back and will be able to figure all that stuff out.

Though ideally you won't have too much old and busted js/css. PREPROCESS ALL THE THINGS!

#### What about the dependencies?

You are now living in a world where projects have static dependencies, much like how python and java projects have dependencies. The way to fetch the latest static dependencies is to run `./hs-static update_deps`.

That will look for a static_conf.json file (more on that later) in each the projects you've listed in `~/.hubspot/config.yaml`. It will use those to gather a list of all the static dependencies you haven't yet installed, download them from s3, and extract them to `~/.hubspot/static-archive`. And when you local server needs to access a dependency (that isn't currently being served as a static project), it will look up the right dependency via `static_conf.json` and the build pointers in `~/.hubspot/static-archive.

I recommend getting into the habit of updating dependencies occasionally (every week-ish?).

#### Come on, can I hit it already?

Alright, alright. I know your HTTP verbs are getting anxious. All you need to do fire up `hs-static run` for your project and hit URLS like these:

  - `http://localhost:3333/your_project/static/sass/file.sass`
  - `http://localhost:3333/your_project/static/css/styles.css`
  - `http://localhost:3333/your_project/static/coffee/project_bundle_name.js`

When you hit SASS/Coffeescript files, the daemon will check filesystem timestamps, automatically compile any necessary changes, and send the processed output directly to you. Similarly, when you hit a bundle file (see more info below) it will check for updates and deliver back the fully concatenated output.

All other files will be passed along as expected.

#### What about bundles (concatenating files together)

It's easy-peasy. Just follow the directions on how to use [manifest files](http://guides.rubyonrails.org/asset_pipeline.html#manifest-files-and-directives). For example, meet my imaginary manifest file located at /project_awesomeness/static/coffee/best-evar.js:

    //= require ./some-file.js
    //= require ./extras/some-other-file.coffee
    //= require_tree ./bunch-o-plugins/
    //= require_directory other_project/static/js/contrib/

This manifest file will join together some-file.js, the compiled output of extras/some-other-file.coffee, any js/coffee file contained in bunch-o-plugins/ (it's recursive), and any js/coffee file that is immediately inside the other_project project's static/js/contrib/ folder.

Fortunately for us, you will still see all of those files included individually while in development mode (with the help of some custom django magic). If you'd like to test things all nice and compressed/obfuscated (like they are in production), just run the daemon like you have before, but add `-m compressed` option to the command.

Note: the ordering of files that come via require\_tree and require\_directory is simply alphabetical. So if you need to insure that some files come before others, just manually require those first. The following directives are smart and won't include any file twice.

Note #2: when requiring files or directories across project boundaries, don't put a '/' in front of the project name. It will cause little teeny kittens to cry.

#### More about that hs-static command

    Usage: hs_static COMMAND [OPTIONS]

    Commands
         start:       Start static server (in the background)
         run:         Start static server, but run in the forground (so you can see the log immediately)
         stop:        Stop static server
         restart:     Restart static server
         log:         Tail the server log (useful when you are running the server in the background)

         precompile:              Precompiles assets to a target directory (does _not_ run the static server).
         precompile_assets_only:  Precompiles assets to a target directory (doesn't build bundle html).

         update_deps:             Downloads the latest dependencies for a project.

    Options
        -m, --mode MODE                  Which mode, local, compressed?
        -p, --static-project PROJECTS    Adds one or more static folders to watch (this paramater can be included multiple times).
                                         This overrides static_projects set in ~/.hubspot/config.yaml.

        -a, --archive-dir DIR            Custom location of the static archive (defaults to ~/.hubspot/static-archive/)
        -c, --clear-cache                Clear the asset cache on startup.

            --production-builds-only     Only use versions of dependencies that are deployed to production

Note: only the basic commands and parameters are listed above. `hs-static help` will list all commands and options (but you probably don't need to worry about most of them).

## Getting into the nitty-gritty

Hopefully the above gave you a good idea about the basics. And if you haven't already, I'd recommend giving `hs-static` a shot with a simple project.


## TODO / Nice-to-haves

- Better identical build detection (for the case that nothing static except for a bundle html file changed)
- Use https://github.com/botandrose/sprockets-image_compressor to losslessly compress images
- Experiment with https://github.com/jwhitley/requirejs-rails to add AMD style loading
- Clean up all the build errors that happen in an "empty" static project
- Make jenkins only update qa build pointers if the whole jenkins build passes (e.g. if the nose tests fail, or a dependency is missing, prevent those static assets from being used).
- Make this easier to run... maybe via an installable gem instead of cloning the repo?




