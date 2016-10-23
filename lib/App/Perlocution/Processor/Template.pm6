use v6;

class App::Perlocution::Processor::Template
does App::Perlocution::Processor
does App::Perlocution::Builder {
    use Template::Anti :ALL;

    multi get-anti-format-object('simple') {
        class {
            method parse($source) {
                class {
                    has $.source;

                    method set($name, $value) {
                        $!source ~~ s:global/'$' $name >/$value/;
                    }

                    method Str { $!source }
                }.new(:$source);
            }
        }
    }

    class Simple {
        has Str $.name;
        has Str $.template;
        has &.render;

        method from-plan(::?CLASS:U: :$name, :$template) {
            sub simple-process($dom, %item) {
                for %item.kv -> $key, $value {
                    $dom.set($key, $value);
                }
            }

            self.new(
                :$name,
                :$template,
                render => anti-template(&simple-process,
                    :source($template),
                    :format<simple>,
                ),
            );
        }

        method template(%item is rw) {
            %item{ $.name } = &.render.(%item)
        }
    }

    class Template::Anti does App::Perlocution::Builder {
        has Str $.name;
        has Str $.template;
        has Str @.include;

        has $.library;

        method from-plan(::CLASS:U:
            :$context,
            :$name,
            :$template,
            :@include,
            :%views,
            :@path,
        ) {
            my %ta-views = %views.kv.map(-> $key, %view-config {
                $key => self.build-from-plan(
                    %view-config,
                    :$context,
                    :type-prefix(Nil),
                    :@include,
                );
            });

            my $library = Template::Anti::Library.new(
                :@path,
                :%views,
            );

            self.new(:$name, :$template, :$library);
        }

        method template(%item is rw) {
            %item{ $.name } = $.library.process($.template, %item);
        }
    }

    has @.templates;

    method from-plan(::?CLASS:U: :$context, :@templates) {
        my @setup-templates = @templates.map(-> %tmpl-conf {
            self.build-from-plan(
                %tmpl-conf,
                :$context,
                :type-prefix(self.^name),
                :section<templates>,
            );
        }

        self.new(:$context, templates => @setup-templates);
    }

    method process(%item is copy) {
        for @.templates -> $template {
            $template.template(%item);
        }

        self.emit(%item);
    }
}