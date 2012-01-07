package App::llinstall;
use 5.008_001;
use strict;
use warnings;
use Getopt::Compact::WithCmd;
use String::ShellQuote;
use File::Spec::Functions qw( catfile catdir );
use File::Path qw( mkpath );
use Cwd;

our $VERSION = '0.01';
#Getopt::Long::Configure("pass_through");

sub new {
    my $class = shift;
    die "not defined LLENV_ROOT" unless(defined $ENV{LLENV_ROOT});
    die "not defined LLENV_OSTYPE" unless(defined $ENV{LLENV_OSTYPE});
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;

    if (! -d $ENV{LLENV_ROOT}) {
        mkpath $ENV{LLENV_ROOT} or die("failed to create $ENV{LLENV_ROOT}: $!");
    }

    if (! -f $self->abs_path('llinstall_config.pl')) {
        open my $fh, '>', $self->abs_path('llinstall_config.pl');
        print {$fh} <<"EOF";
+{
    common => {
    },
    perl => {
        env     => 'export PERLBREW_ROOT=\$LLENV_ROOT/lls/\$LLENV_OSTYPE/perl; export PERLBREW_HOME=\$LLENV_ROOT/lls/\$LLENV_OSTYPE/perl;',
        init    => 'curl -kL http://install.perlbrew.pl | bash',
        install => 'source \$PERLBREW_ROOT/etc/bashrc && perlbrew install --notest',
        ll_dir  => '\$LLENV_ROOT/lls/\$LLENV_OSTYPE/perl/perls',
    },
    ruby => {
        env     => 'export RBENV_ROOT=\$LLENV_ROOT/lls/\$LLENV_OSTYPE/ruby; export PATH=\$RBENV_ROOT/bin:\$PATH;',
        init    => 'GIT_SSL_NO_VERIFY=true git clone https://github.com/sstephenson/rbenv.git \$RBENV_ROOT && GIT_SSL_NO_VERIFY=true git clone https://github.com/sstephenson/ruby-build.git \$RBENV_ROOT/ruby-build && (cd \$RBENV_ROOT/ruby-build && PREFIX=\$RBENV_ROOT ./install.sh)',
        install => 'eval "\$(rbenv init -)" && rbenv install',
        ll_dir  => '\$LLENV_ROOT/lls/\$LLENV_OSTYPE/ruby/versions',
    },
    python => {
        env     => 'export PYTHONBREW_ROOT=\$LLENV_ROOT/lls/\$LLENV_OSTYPE/python; export PYTHONBREW_HOME=\$LLENV_ROOT/lls/\$LLENV_OSTYPE/python;',
        init    => 'curl -kL http://xrl.us/pythonbrewinstall | bash',
        install => 'source \$PYTHONBREW_ROOT/etc/bashrc && pythonbrew install --verbose --no-test',
        ll_dir  => '\$LLENV_ROOT/lls/\$LLENV_OSTYPE/python/pythons',
    },
    node => {
        env     => 'export NVM_DIR=\$LLENV_ROOT/lls/\$LLENV_OSTYPE/node;',
        init    => 'GIT_SSL_NO_VERIFY=true git clone https://github.com/creationix/nvm.git \$NVM_DIR',
        install => 'source \$NVM_DIR/nvm.sh; nvm install',
        ll_dir  => '\$LLENV_ROOT/lls/\$LLENV_OSTYPE/node',
    },
};
EOF
        close $fh;
    }
    $self->{'conf'} = _get_config_pl(catfile($ENV{LLENV_ROOT}, 'llinstall_config.pl'));
}

sub parse_options {
    my $self = shift;
    
    my $go = Getopt::Compact::WithCmd->new(
        name          => 'llinstall',
        version       => $VERSION,
        command_struct => {
            init => {
                desc        => 'init llinstall',
                args        => 'LL',
            },
            install => {
                desc        => 'install LL',
                args        => 'LL VERSION',
            },
            list => {
                desc        => 'list LL',
                args        => 'LL',
            },
            path => {
                desc        => 'LL path',
                args        => 'LL VERSION',
            },
            exec => {
                desc        => 'LL use(only add to PATH)',
                args        => 'LL VERSION OPTIONS',
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
    $self->{'go'}->show_usage unless(scalar @args == 1);
    my ($ll) = @args;
    die "not found $ll in llinstall_config.pl" unless(defined $self->{conf}->{$ll});
    my $conf = $self->{'conf'}->{$ll};

    system("$conf->{'env'} $conf->{'init'}");
}

sub command_install {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage unless(scalar @args == 2);
    my ($ll, $version) = @args;
    die "not found $ll in llinstall_config.pl" unless(defined $self->{conf}->{$ll});
    my $conf = $self->{'conf'}->{$ll};

    system("$conf->{'env'} $conf->{'install'} $version");
}

sub command_list {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage unless(scalar @args == 1);
    my ($ll) = @args;
    die "not found $ll in llinstall_config.pl" unless(defined $self->{conf}->{$ll});
    my $conf = $self->{'conf'}->{$ll};

    my $LLENV_ROOT = $ENV{LLENV_ROOT};
    my $LLENV_OSTYPE = $ENV{LLENV_OSTYPE};
    my $ll_dir = eval "qq{$conf->{'ll_dir'}}";

    opendir my $dh, $ll_dir or die "cannot opendir $ll_dir";
    for my $dir (sort readdir $dh) {
        next if($dir eq '.' or $dir eq '..');
        next unless(-d catfile($ll_dir, $dir));
        print "$dir\n";
    }
}

sub command_path {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage unless(scalar @args == 2);
    my ($ll, $version) = @args;
    die "not found $ll in llinstall_config.pl" unless(defined $self->{conf}->{$ll});
    my $conf = $self->{'conf'}->{$ll};

    my $path = catfile($conf->{'ll_dir'}, $version, 'bin', $ll);
    my $LLENV_ROOT = $ENV{LLENV_ROOT};
    my $LLENV_OSTYPE = $ENV{LLENV_OSTYPE};
    my $abs_path = eval "qq{$path}";
    die "not found $abs_path" unless(-f $abs_path);
    print $path."\n";
}

sub command_exec {
    my ($self, @args) = @_;
    $self->{'go'}->show_usage unless(scalar @args >= 2);
    my ($ll, $version, @options) = @args;
    die "not found $ll in llinstall_config.pl" unless(defined $self->{conf}->{$ll});
    my $conf = $self->{'conf'}->{$ll};

    my $path = catfile($conf->{'ll_dir'}, $version, 'bin', $ll);
    my $LLENV_ROOT = $ENV{LLENV_ROOT};
    my $LLENV_OSTYPE = $ENV{LLENV_OSTYPE};
    my $abs_path = eval "qq{$path}";
    die "not found $abs_path" unless(-f $abs_path);

    print("$abs_path ". shell_quote @options);
    exec("$abs_path ". shell_quote(@options));
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
