package App::llenv;
use 5.008_001;
use strict;
use warnings;
use Getopt::Compact::WithCmd;
use File::Spec::Functions qw( catfile catdir );
use File::Path qw( mkpath );
use Cwd;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;

    if (! -d $ENV{LLENV_ROOT}) {
        mkpath $ENV{LLENV_ROOT} or die("failed to create $ENV{LLENV_ROOT}: $!");
    }

    if (! -f $self->abs_path('config.pl')) {
        open my $fh, '>', $self->abs_path('config.pl');
        print {$fh} <<"EOF";
+{
    common => {
        app_dir => 'apps',
        bin_dir => 'bin',
    },
    perl => {
        env_bundle_lib   => 'PERL5OPT',
        env_app_lib      => 'PERL5OPT',
        tmpl_bundle_lib  => 'local/lib/perl5',
        tmpl_bundle_path => 'local/bin',
        tmpl_app_lib     => 'lib',
        tmpl_app_path    => 'bin',
    },
    ruby => {
        env_bundle_lib   => 'GEM_PATH',
        env_app_lib      => 'RUBYLIB',
        tmpl_bundle_lib  => 'vendor/bundle/ruby/1.9.1',
        tmpl_bundle_path => 'vendor/bundle/ruby/1.9.1/bin',
        tmpl_app_lib     => 'lib',
        tmpl_app_path    => 'bin',
    },
    python => {
        env_bundle_lib   => 'PYTHONPATH',
        env_app_lib      => 'PYTHONPATH',
        tmpl_bundle_lib  => 'lib/python2.7/site-packages',
        tmpl_bundle_path => 'bin',
        tmpl_app_lib     => 'lib',
        tmpl_app_path    => 'bin',
    },
    node => {
        env_bundle_lib   => 'NODE_PATH',
        env_app_lib      => 'NODE_PATH',
        tmpl_bundle_lib  => 'node_modules',
        tmpl_bundle_path => 'node_modules/.bin',
        tmpl_app_lib     => 'lib',
        tmpl_app_path    => 'bin',
    },
};
EOF
        close $fh;
    }
    $self->{'conf'} = _get_config_pl(catfile($ENV{LLENV_ROOT}, 'config.pl'));

    my $app_dir = $self->abs_path($self->{'conf'}->{'common'}->{'app_dir'});
    my $bin_dir = $self->abs_path($self->{'conf'}->{'common'}->{'bin_dir'});
    for my $path ($app_dir, $bin_dir) {
        if (! -d $path) {
            mkpath $path or die("failed to create $path: $!");
        }
    }
}

sub parse_options {
    my $self = shift;
    
    my $go = Getopt::Compact::WithCmd->new(
        name          => 'llenv',
        version       => $VERSION,
        command_struct => {
            init => {
                desc        => 'init llenv',
            },
            setup => {
                options     => [
                    [ [qw/l ll/], 'LL', '=s', undef, { required => 1 } ],
                    [ [qw/v version/], 'LL version', '=s' ],
                ],
                desc        => 'setup llenv app dir',
                args        => 'APP_NAME',
            },
            exec => {
                desc        => 'exec cwd script',
                args        => 'SCRIPT_NAME[ -- SCRIPTOPTIONS]',
            },
            install => {
                desc        => 'install cwd script to bin dir',
                args        => 'SCRIPT_NAME',
            },
        },
    );

    $self->{'go'} = $go;
    $self->{'command'} = $go->command || $go->show_usage;
    $self->{'opts'} = $go->opts;
}

sub run {
    my($self) = @_;
    $self->can('command_' . $self->{'command'})->($self, @ARGV);
}

sub command_init {
    my ($self, @args) = @_;
    print <<EOF;
llenv init

export LLENV_ROOT=$ENV{LLENV_ROOT}
export PATH=\$LLENV_ROOT/bin:\$PATH

EOF
}

sub command_install {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage unless(scalar @args == 1);
    my $script = shift @args;
    my ($ll, $script_file, $env) = $self->get_script_env($script);
    $self->set_env($env);

    my $bin_dir = $self->{'conf'}->{'common'}->{'bin_dir'};
    if (! -d $self->abs_path($bin_dir)) {
        mkpath $self->abs_path($bin_dir)
            or die "failed to create $bin_dir: $!";
    }

    my $abs_script = $self->abs_path($bin_dir, $script);
    my $export_env = join "\n", map { "export $_=\"$env->{$_}\$$_\"" } keys %$env;
    open my $fh, '>', $abs_script;
    print {$fh} <<"EOF";
#!/bin/sh
$export_env
exec /usr/bin/env $ll $script_file "\$@"
EOF
    close $fh;
    system("chmod +x $abs_script");
}

sub command_exec {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage if(scalar @args < 1);
    my $script = shift @args;

    my ($ll, $script_file, $env) = $self->get_script_env($script);
    $self->set_env($env);
    system("/usr/bin/env $ll $script_file @args");
}

sub set_env {
    my ($self, $env) = @_;
    my $LLENV_ROOT = $ENV{LLENV_ROOT};
    for (keys %$env) {
        $ENV{$_} = '' unless defined $ENV{$_};
        my $str = eval "qq{$env->{$_}}";
        $ENV{$_} = $str.$ENV{$_};
    }
}

sub get_script_env {
    my ($self, $script) = @_;

    my $llenv_file = catdir(getcwd, '.llenv.pl');
    my $app_conf = _get_config_pl($llenv_file);
    my $ll = (keys %{$app_conf})[0];
    my $conf = $app_conf->{$ll};

    my $local_path = $self->get_local_path($conf);
    my $script_file = $self->get_script_path($conf, $script);
    my ($env_bundle_lib, $bundle_lib) = $self->get_bundle_lib($ll, $conf->{'bundle_lib'});
    my ($env_app_lib, $app_lib) = $self->get_app_lib($ll, $conf->{'app_lib'});
    my $env = {
        'PATH' => $local_path,
    };
    $env->{$env_bundle_lib} .= $bundle_lib;
    $env->{$env_app_lib} .= $app_lib;

    return ($ll, $script_file, $env);
}

sub get_script_path {
    my ($self, $conf, $script) = @_;
    for (qw/app_path bundle_path/) {
        next unless(defined $conf->{$_});
        my $full_path = $self->abs_path($conf->{$_}, $script);
        return catfile('$LLENV_ROOT', $conf->{$_}, $script) if(-f $full_path);
    }
    die "not found $script";
}

sub get_local_path {
    my ($self, $conf) = @_;
    my $path = '';
    for (qw/bundle_path app_path/) {
        next unless(defined $conf->{$_});
        my $_path = catdir('$LLENV_ROOT', $conf->{$_});
        $path = "$_path:$path";
    }
    return $path;
}

sub get_bundle_lib {
    my ($self, $ll, $lib) = @_;
    my $env_bundle_lib = $self->{'conf'}->{$ll}->{'env_bundle_lib'};
    $lib = catdir('$LLENV_ROOT', $lib);
    if ($ll eq 'perl') {
        $lib = "-Mlib=$lib ";
    } else {
        $lib = "$lib:";
    }
    return ($env_bundle_lib, $lib);
}

sub get_app_lib {
    my ($self, $ll, $lib) = @_;
    my $env_app_lib = $self->{'conf'}->{$ll}->{'env_app_lib'};
    $lib = catdir('$LLENV_ROOT', $lib);
    if ($ll eq 'perl') {
        $lib = "-Mlib=$lib ";
    } else {
        $lib = "$lib:";
    }
    return ($env_app_lib, $lib);
}

sub command_setup {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage unless(scalar @args == 1);
    my $app_name = $args[0];
    my $opts = $self->{'opts'};
    my $conf = $self->{'conf'}->{$opts->{'ll'}}
        or die("not found $opts->{'ll'} conf");

    my $app_dir = catdir($self->{'conf'}->{'common'}->{'app_dir'}, $app_name);
    my $app_bundle_lib = catdir($app_dir, $conf->{'tmpl_bundle_lib'});
    my $app_bundle_path = catdir($app_dir, $conf->{'tmpl_bundle_path'});
    my $app_lib = catdir($app_dir, $conf->{'tmpl_app_lib'});
    my $app_path = catdir($app_dir, $conf->{'tmpl_app_path'});

    if (! -d $self->abs_path($app_dir)) {
        mkpath $self->abs_path($app_dir)
            or die("failed to create $app_dir: $!");
    }

    open my $fh, '>', $self->abs_path($app_dir, '.llenv.pl');
    print {$fh} <<"EOF";
+{
    $opts->{'ll'} => {
        bundle_lib => '$app_bundle_lib',
        bundle_path => '$app_bundle_path',
        app_lib => '$app_lib',
        app_path => '$app_path',
    },
}
EOF
    close $fh;
}

sub abs_path {
    my ($self, @path) = @_;
    return catdir($ENV{LLENV_ROOT}, @path);
}

sub _get_config_pl {
    my ($fname) = @_;
    my $config = do $fname;
    die("$fname: $@") if $@;
    die("$fname: $!") unless defined $config;
    unless ( ref($config) eq 'HASH' ) {
        die("$fname does not return HashRef.");
    }
    return $config;
}

1;
__END__

=head1 NAME

App::llenv - Perl extention to do something

=head1 VERSION

This document describes App::llenv version 0.01.

=head1 SYNOPSIS

    use App::llenv;

=head1 DESCRIPTION

# TODO

=head1 INTERFACE

=head2 Functions

=head3 C<< hello() >>

# TODO

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<perl>

=head1 AUTHOR

riywo E<lt>riywo.jp@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, riywo. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
