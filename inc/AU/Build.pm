package AU::Build;

use strict;
use warnings;
use parent 'Alien::Base::ModuleBuild';

use Alien::ProtoBuf;
use ExtUtils::CBuilder;
use ExtUtils::CppGuess;
use Config;
use Cwd;

my $base = Cwd::cwd;
my $commit = 'b0976f608b40fb320263f399e83f4ad9d5f3bd68';

sub new {
    my $class = shift;
    my $protobuf_flags = Alien::ProtoBuf->cflags;
    my $self = $class->SUPER::new(
        @_,
        alien_name            => 'uPB', # to stop Alien::Base warnings
        alien_build_commands => [
            "$Config{make} default googlepb USER_CPPFLAGS=\"$protobuf_flags -fPIC\"",
        ],
        alien_install_commands => [
            "$^X ../../scripts/install.pl %s",
        ],
        alien_repository => {
            protocol        => 'http',
            exact_filename  => "http://github.com/mbarbon/upb/archive/$commit.zip",
        },
    );

    return $self;
}

sub alien_check_built_version {
    my($self) = @_;

    my $builder = ExtUtils::CBuilder->new(quiet => 0);

    die "C++ compiler not found"
        unless $builder->have_cplusplus;

    my %cxx_flags = ExtUtils::CppGuess->new->module_build_options;
    my ($version, $flags) = _check_flags(
        $builder, \%cxx_flags,
        compiler_flags  => '-I. ' . Alien::ProtoBuf->cflags,
        linker_flags    => '-Llib -lupb.bindings.googlepb -lupb ' . Alien::ProtoBuf->libs,
    );

    die "It seems something went wrong while building uPB"
        unless $version;

    return $version;
}

sub alien_generate_manual_pkgconfig {
    my $self = shift;
    my $config = $self->SUPER::alien_generate_manual_pkgconfig(@_);

    $config->{keywords}{Cflags} = '-I${pcfiledir}/include';
    $config->{keywords}{Libs} =
        '-L${pcfiledir}/lib ' .
        join " ", map "-l$_", qw(
            upb.bindings.googlepb upb.pb upb.json upb.descriptor upb
        );

    return $config;
}

sub _check_flags {
    my ($builder, $cxx_flags, %flags) = @_;
    my $object = $builder->object_file($base . '/inc/AU/test.cpp');
    my $exe = $builder->exe_file($object);

    $builder->compile(
        source               => $base . '/inc/AU/check_upb.cpp',
        object_file          => $object,
        extra_compiler_flags =>
            join(' ',
                 $cxx_flags->{extra_compiler_flags} // '',
                 $flags{compiler_flags} // ''),
    );
    $builder->link_executable(
        objects            => [$object],
        extra_linker_flags =>
            join(' ',
                 $cxx_flags->{extra_linker_flags} // '',
                 $flags{linker_flags} // ''),
    );

    my $version = qx($exe);

    return ($version, \%flags);
}

1;
