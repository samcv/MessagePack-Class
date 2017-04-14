use v6.c;

role MessagePack::Class {
    use Data::MessagePack;

    method from-messagepack(Blob $pack) {
        _unmarshal(Data::MessagePack::unpack($pack), self);
    }


    my role CustomUnmarshaller {
        method unmarshal($value, Mu:U $type) {
            ...
        }
    }

    my role CustomUnmarshallerCode does CustomUnmarshaller {
        has &.unmarshaller is rw;

        method unmarshal($value, Mu:U $type) {
            self.unmarshaller.($value);
        }
    }

    my role CustomUnmarshallerMethod does CustomUnmarshaller {
        has Str $.unmarshaller is rw;
        method unmarshal($value, Mu:U $type) {
            my $meth = self.unmarshaller;
            $type."$meth"($value);
        }
    }

    multi sub trait_mod:<is> (Attribute $attr, :&unpacked-by!) is export {
        $attr does CustomUnmarshallerCode;
        $attr.unmarshaller = &unpacked-by;
    }

    multi sub trait_mod:<is> (Attribute $attr, Str:D :$unpacked-by!) is export {
        $attr does CustomUnmarshallerMethod;
        $attr.unmarshaller = $unpacked-by;
    }

    sub panic($data, $type) {
        die "Cannot unmarshal {$data.perl} to type {$type.perl}"
    }

    multi _unmarshal(Any:U, Mu $type) {
        $type;
    }

    multi _unmarshal(Any:D $data, Int) {
        if $data ~~ Int {
            return Int($data)
        }
        panic($data, Int)
    }

    multi _unmarshal(Any:D $data, Rat) {
        CATCH {
            default {
                panic($data, Rat);
            }
        }
        return Rat($data);
    }

    multi _unmarshal(Any:D $data, Numeric) {
        if $data ~~ Numeric {
            return Num($data)
        }
        panic($data, Numeric)
    }

    multi _unmarshal($data, Str) {
        if $data ~~ Stringy {
            return Str($data)
        }
        else {
            Str;
        }
    }

    multi _unmarshal(Any:D $data, Bool) {
        CATCH {
            default {
                panic($data, Bool);
            }
        }
        return Bool($data);
    }

    multi _unmarshal(Any:D $data, Any $x) {
        my %args;
        my %local-attrs =  $x.^attributes(:local).map({ $_.name => $_.package });
        for $x.^attributes -> $attr {
            if %local-attrs{$attr.name}:exists && !(%local-attrs{$attr.name} === $attr.package ) {
                next;
            }
            my $data-name = $attr.name.substr(2);
            if $data{$data-name}:exists {
                %args{$data-name} := do if $attr ~~ CustomUnmarshaller {
                    $attr.unmarshal($data{$data-name}, $attr.type);
                }
                else {
                    _unmarshal($data{$data-name}, $attr.type);
                }
            }
        }
        return $x.new(|%args)
    }

    multi _unmarshal($data, @x) {
        my @ret;
        for $data.list -> $value {
            my $type = @x.of =:= Any ?? $value.WHAT !! @x.of;
            @ret.append(_unmarshal($value, $type));
        }
        return @ret;
    }

    multi _unmarshal($data, %x) {
        my %ret;
        for $data.kv -> $key, $value {
            my $type = %x.of =:= Any ?? $value.WHAT !! %x.of;
            %ret{$key} = _unmarshal($value, $type);
        }
        return %ret;
    }

    multi _unmarshal(Any:D $data, Mu) {
        return $data
    }

    method to-messagepack(--> Blob) {
        Data::MessagePack::pack(_marshal(self));
    }

    my role CustomMarshaller {
        method marshal($value, Mu:D $object) {
            ...
        }
    }

    my role CustomMarshallerCode does CustomMarshaller {
        has &.marshaller is rw;

        method marshal($value, Mu:D $object) {
            # the dot below is important otherwise it refers
            # to the accessor method
            self.marshaller.($value);
        }
    }

    my role CustomMarshallerMethod does CustomMarshaller {
        has Str $.marshaller is rw;
        method marshal($value, Mu:D $type) {
            my $meth = self.marshaller;
            $value.defined ?? $value."$meth"() !! $type;
        }
    }

    multi sub trait_mod:<is> (Attribute $attr, :&packed-by!) is export {
        $attr does CustomMarshallerCode;
        $attr.marshaller = &packed-by;
    }

    multi sub trait_mod:<is> (Attribute $attr, Str:D :$packed-by!) is export {
        $attr does CustomMarshallerMethod;
        $attr.marshaller = $packed-by;
    }

    my role SkipNull {
    }

    multi sub trait_mod:<is> (Attribute $attr, :$pack-skip-null!) is export {
        $attr does SkipNull;
    }

    multi sub _marshal(Cool $value, Bool :$skip-null) {
        $value;
    }

    multi sub _marshal(%obj, Bool :$skip-null) returns Hash {
        my %ret;

        for %obj.kv -> $key, $value {
            %ret{$key} = _marshal($value, :$skip-null);
        }

        %ret;
    }

    multi sub _marshal(@obj, Bool :$skip-null) returns Array {
        my @ret;

        for @obj -> $item {
            @ret.push(_marshal($item, :$skip-null));
        }
        @ret;
    }

    multi sub _marshal(Mu $obj, Bool :$skip-null) returns Hash {
        my %ret;
        my %local-attrs =  $obj.^attributes(:local).map({ $_.name => $_.package });
        for $obj.^attributes -> $attr {
            if %local-attrs{$attr.name}:exists && !(%local-attrs{$attr.name} === $attr.package ) {
                next;
            }
            if $attr.has_accessor {
                my $name = $attr.name.substr(2);
                my $value = $attr.get_value($obj);
                if serialise-ok($attr, $value, $skip-null) {
                    %ret{$name} = do if $attr ~~ CustomMarshaller {
                        $attr.marshal($value, $obj);
                    }
                    else {
                        _marshal($value);
                    }
                }

            }
        }
        %ret;
    }

    sub serialise-ok(Attribute $attr, $value, Bool $skip-null ) returns Bool {
        my $rc = True;
        if $skip-null || ( $attr ~~ SkipNull ) {
            if not $value.defined {
                $rc = False;
            }
        }
        $rc;
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
