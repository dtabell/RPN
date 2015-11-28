#!/usr/bin/env perl
#
#  RPN: a Reverse Polish Notation calculator
#  Dan T. Abell, February 2001
#  dabell69@earthlink.net
#

#DEBUG: print "Perl version \$] = ", $], "\n";
#DEBUG: print "\$0 = ", $0, "\n";
#DEBUG: print "__FILE__ = ", __FILE__, "\n";

# directories
$RPN_BIN_DIR = "BINDIR";
$RPN_DIR = "RPNDIR";

# history file
$RPN_HISTORY = "$RPN_DIR/rpn_history";
$MAX_HISTORY = 1000;

# for Perl modules in a local library
#use local::lib

use POSIX qw(acos asin atan ceil cosh floor
             fmod log10 modf pow sinh tan tanh);
use Text::Wrap;
use Term::ReadLine;

# the following two lines are useful for
# debugging the finding of Perl modules
#DEBUG: print '@INC = ',"@INC","\n\n";
#DEBUG: print "key: $_\t\t value: $INC{$_}\n" foreach (keys %INC);


# SI prefix conversion table
%SI = (
  Y  => 1.e+24, # yotta
  Z  => 1.e+21, # zetta
  E  => 1.e+18, # exa
  P  => 1.e+15, # peta
  T  => 1.e+12, # tera
  G  => 1.e+09, # giga
  M  => 1.e+06, # mega
  k  => 1.e+03, # kilo
  K  => 1.e+03, # kilo
  h  => 1.e+02, # hecto
  da => 1.e+01, # deka
  d  => 1.e-01, # deci
  c  => 1.e-02, # centi
  m  => 1.e-03, # milli
  u  => 1.e-06, # micro
  n  => 1.e-09, # nano
  p  => 1.e-12, # pico
  f  => 1.e-15, # femto
  a  => 1.e-18, # atto
  z  => 1.e-21, # zepto
  y  => 1.e-24, # yocto
);

@stack=();
@old_stack=();

$fussy=1;  # if 0, RPN will overwite functions and variables silently

%cabbrevs=();   # $cabbrevs{$cname} := string of abbreviations for $cname
%cdescr=();     # $cdescr{$cname}   := string describing constant $cname
%cnames=();     # $cnames{$c}       := name of constant corresponding to $c
%cvalues=();    # $cvalues{$cname}  := value of constant $cname
%ops=();        # $ops{$op}         := name of operation corresponding to $op
%functions=();  # $functions{$fn}   := user-defined function $fn
%vars=();       # $vars{$var}       := user-defined variable $var

$angle_unit="radian";
$print_mode="standard";
$print_precision=6;
$stack_display=6;
$precision_max=50;
$display_max=500;

$deg_per_rad  = 57.2957795130823208768;
$euler_e      =  2.71828182845904523536;
$golden_ratio =  1.61803398874989484820;
$pi           =  3.14159265358979323846;
$twopi        = 2*$pi;

init_ops      ("$RPN_DIR/base/ops.rpn");
init_fns      ("$RPN_DIR/base/fns.rpn");
#init_constants("$RPN_DIR/base/constants2006.rpn");
init_constants("$RPN_DIR/base/constants2014.rpn");


# if command-line arguments exist, process them and exit
if($#ARGV>=0){
  $opt=shift(@ARGV);
  if($opt eq "-e"){
    $args=join(" ",@ARGV);
    rpn_parse("$args");
    print_stack($stack_display);
  }
  elsif($opt eq "-f"){
    print "Sorry: \"rpn -f filename\" not yet implemented.\n";
  }
  else{die "Usage: rpn [-e 'rpn commands' | -f filename].";}
  exit;
}

# otherwise, run interactively
RPNbanner();

$RPNterm = new Term::ReadLine "RPNcalc";
$RPNterm->ornaments(0);
$RPNterm->read_history("$RPN_HISTORY");

#DEBUG: print "ReadLine support: ", $RPNterm->ReadLine,"\n\n";

$RPNlc = 1;  # initialize line counter
while(1){
  $_ = $RPNterm->readline("rpn:$RPNlc> ");
     if(/^\s*$/ || /^\s*\#/){--$RPNlc;} # ignore blank lines and comment lines
  elsif(/^\s*undo\s*$/){switch_stacks(); print_stack($stack_display);}
  elsif(/^\s*:fn:\s*(.*)/){function_def($1); print_stack($stack_display);}
  else{$f=rpn_parse($_);
       if(!defined($f) || $f ne "stk" && $f ne "stk2" && $f ne "stkn"){
         print_stack($stack_display);}}
  ++$RPNlc;
}


#
# subroutines
#
sub agm {  # arithmetic-geometric mean
  my($a,$b)=@_;
  my $tol=1.e-15;
  while(abs($b-$a)>$tol){
    ($a,$b)=(sqrt($a*$b),0.5*($a+$b));
  }
  return($a);
}

sub angle_unit_to_radian {
  my($ang)=@_;
  if($angle_unit eq "radian"   ){return $ang;}
  if($angle_unit eq "gradian"  ){return $ang*$pi/200;}
  if($angle_unit eq "degree"   ){return $ang/$deg_per_rad;}
  if($angle_unit eq "degminsec"){return dms2d($ang)/$deg_per_rad;}
}

sub argsQ {
  my($op,$n)=@_;
  my($ok) = $#stack+1 >= $n;
  if(!$ok){warn "ERROR: too few arguments for \"$op\".\n";}
  return $ok;
}

sub binomial {
  my($n,$k)=@_;
  my($bin,$k1)=(1,$n-$k);
  if($k<0 || $k>$n){return(0);}
  elsif($k==0 || $k==$n){return($bin);}
  else{if($k<$k1){($k,$k1)=($k1,$k);}
       foreach $i (1..$k1){$bin*=($k+$i)/$i;}
       return($bin);}
}

sub cosc {  # double precision (1-cos(x))/x^2
  my($ang)=@_;
  my($ang2);
  if(abs($ang)>=0.500){return((1-cos($ang))/$ang**2);}
  else{$ang2=$ang*$ang;
       return(1/2.-$ang2/24.*(1-$ang2/30.*(1-$ang2/56.
              *(1-$ang2/90.*(1-$ang2/132.*(1-$ang2/182.))))));}
}

sub d2dms {
  my($d)=@_;
  my($deg)=floor($d);
  my($min)=floor(($d-$deg)*60);
  my($sec)=($d-$deg-$min/60)*3600;
  return($deg + $min/100. + $sec/10000.);
}

sub dms2d {
  my($dms)=@_;
  my($deg)=floor($dms);
  my($min)=floor(($dms-$deg)*100.);
  my($sec)=($dms-$deg-$min/100)*10000.;
  return($deg + $min/60. + $sec/3600.);
}

sub factorial {
  my($n)=@_;
  my($nf)=(1);
  if($n==0 || $n==1){return($nf);}
  else{foreach $k (2..$n){$nf*=$k;}
       return($nf);}
}

sub function_def {
  my($line)=@_;
  my($fname,$defn,$cmnt)=("","","");
  $line.="\n";
  {if($line=~s/\s*:\s*([a-zA-Z_]\w*)\s*(\#.*)?$//){$fname=$1; $cmnt=$2}
   $defn.=$line;
   if($fname eq ""){$line=<>; redo}
  }
  if($cmnt ne ""){chomp($defn); $defn.=" $cmnt\n";}
  $defn=~s/^\s*//; $defn=~s/\s*$//;
  $fname=get_name($fname);
  $functions{$fname}=$defn;
}

sub get_name {
  my($name)=@_;
  my($a,$nm);
  while(1){
    if(!nameQ($name)){warn "ERROR: \"$name\" is not a valid name.";}
    elsif(defined($nm=$cnames{$name})){
      warn "ERROR: can't redefine \"$name\" := $cdescr{$nm}.\n";}
    elsif($fussy && (defined($vars{$name}) || defined($functions{$name}))){
      warn "WARNING: do you wish to overwrite \"$name\"?\n";
      print "  "; $a=<STDIN>;
      if($a=~/^\s*(y|ye|yes)\s*$/){last;}}
    else{last;}
    print " Enter new name: "; $name=<STDIN>;
    $name=~s/^\s*//; $name=~s/\s*$//;
  }
  return($name);
}

sub init_constants {
  my($constfile)=@_;
  my($cname,$cval,@abbrevs)=();
  open(F,$constfile)
    || open(F,"$RPN_DIR/$constfile")
    || open(F,"$RPN_DIR/user/$constfile")
    || open(F,"$RPN_DIR/lib/$constfile")
    || open(F,"$RPN_DIR/base/$constfile")
    || (warn("ERROR: can't open \"$constfile\": $!.\n") && return);
  while(<F>){
    if(/^\s*$/ || /^\s*\#/){next;}  # ignore blank lines and comment lines
    chomp; s/\s*\#.*//; ($cname,$cval)=split;
    $cvalues{$cname}=$cval+0;
    $_=<F>; chomp; s/^\s+//; s/\s*\# (.*)//; @abbrevs=split;
    $cabbrevs{$cname}=$_; $cdescr{$cname}=$1;
    foreach $c (@abbrevs) {$cnames{$c}=$cname};
  }
  close(F) || (warn("ERROR: can't close \"$constfile\": $!.\n") && return);
}

sub init_fns {
  my($fnsfile)=@_;
  my($fn,$defn,$cmnt,$line)=("","","","");
  open(F,$fnsfile)
    || open(F,"$RPN_DIR/$fnsfile")
    || open(F,"$RPN_DIR/user/$fnsfile")
    || open(F,"$RPN_DIR/lib/$fnsfile")
    || open(F,"$RPN_DIR/base/$fnsfile")
    || (warn("ERROR: can't open \"$fnsfile\": $!.\n") && return);
  while(<F>){
    if(/^\s*$/ || /^\s*\#/){next;} # ignore blank lines and comment lines
    $line=$_; $line=~s/^\s*:fn:\s*//;
    {if($line=~s/\s*:\s*([a-zA-Z_]\w*)\s*(\#.*)?$//){$fn=$1; $cmnt=$2;}
     $defn.=$line;
     if($fn eq ""){$line=<F>; redo}
    }
    if($cmnt ne ""){chomp($defn); $defn.=" $cmnt\n";}
    $defn=~s/^\s*//; $defn=~s/\s*$//;
    $functions{$fn}=$defn;
    ($fn,$defn,$cmnt,$line)=("","","","");
  }
  close(F) || (warn("ERROR: can't close \"$fnsfile\": $!.\n") && return);
}

sub init_ops {
  my($opsfile)=@_;
  my($op,$type);
  open(F,$opsfile)
    || open(F,"$RPN_DIR/base/$opsfile")
    || open(F,"$RPN_DIR/lib/$opsfile")
    || open(F,"$RPN_DIR/user/$opsfile")
    || open(F,"$RPN_DIR/$opsfile")
    || die("ERROR: can't open \"$opsfile\": $!.\n");
  while(<F>){
    if(/^\s*$/ || /^\s*\#/){next;}  # skip blank and comment lines
    chomp; ($op,$type)=split;
    $ops{$op}=$type;
  }
  close(F) || (warn("ERROR: can't close \"$opsfile\": $!.\n") && return);
}

sub integerQ {
  return($_[0]==int($_[0]));
}

sub name_rmv {
  my($rmv)=@_;
  my(@rmv);
  $rmv=~s/[()]//g;
  @rmv=split(/,/,$rmv);
  foreach $rmv (@rmv){
    if(defined($vars{$rmv})){delete $vars{$rmv};}
    elsif(defined($functions{$rmv})){delete $functions{$rmv};}
    else{warn "ERROR: can't delete undefined quantity \"$rmv\".\n";}}
}

sub nameQ {
  return($_[0] =~ /^[a-zA-Z_]\w*$/);
}

sub name_rmvQ {
  return($_[0] =~ /^\(([a-zA-Z_]\w*,?)+\)?$/);
}

sub numberQ {
#  return($_[0] =~ /^[+-]?\d+\.?\d*(e\d+|e\+\d+|e\-\d+)?$/i ||
#         $_[0] =~ /^[+-]?\.\d+(e\d+|e\+\d+|e\-\d+)?$/i);
     if($_[0] =~ /^[+-]?\d+\.?\d*(e\d+|e\+\d+|e\-\d+)?$/i ||
        $_[0] =~ /^[+-]?\.\d+(e\d+|e\+\d+|e\-\d+)?$/i){return 1;}
  elsif($_[0] =~ /^[+-]?\d+\.?\d*(d\d+|d\+\d+|d\-\d+)?$/i ||
        $_[0] =~ /^[+-]?\.\d+(d\d+|d\+\d+|d\-\d+)?$/i){
        $_[0] =~s/d/e/i;
        return 1;
  } else {return 0;}
}

sub operation {
  my($e)=@_;
  # basic arithmetic
     if($e eq "+"  ){if(argsQ($e,2)){$x=shift(@stack); $stack[0]+=$x;}}
  elsif($e eq "-"  ){if(argsQ($e,2)){$x=shift(@stack); $stack[0]-=$x;}}
  elsif($e eq "*"  ){if(argsQ($e,2)){$x=shift(@stack); $stack[0]*=$x;}}
  elsif($e eq "/"  ){if(argsQ($e,2)){$x=shift(@stack);
                                     if($x!=0){$stack[0]/=$x;}
                                     else{warn "ERROR: can't divide by zero.\n";
                                          unshift(@stack,$x);}}}
  elsif($e eq "++" ){if(argsQ($e,1)){$stack[0]++;}}
  elsif($e eq "--" ){if(argsQ($e,1)){$stack[0]--;}}
  elsif($e eq "+++"){if(argsQ($e,2)){$x=shift(@stack); $y=$stack[0];
                                     $stack[0]=sqrt($y*$y+$x*$x);}}
  elsif($e eq "+-+"){if(argsQ($e,2)){$x=shift(@stack); $y=$stack[0];
                       if(abs($y)>=abs($x)){$stack[0]=sqrt($y*$y-$x*$x);}
                       else{warn "ERROR: can't form pythagorean diffence $y +-+ $x.\n";
                            unshift(@stack,$x);}}}
  elsif($e eq "tm+"){if(argsQ($e,2)){$x=shift(@stack); $y=$stack[0];
                                     $stack[0]=d2dms(dms2d($y)+dms2d($x));}}
  elsif($e eq "tm-"){if(argsQ($e,2)){$x=shift(@stack); $y=$stack[0];
                                     $stack[0]=d2dms(dms2d($y)-dms2d($x));}}
  elsif($e eq "inv"){if(argsQ($e,1)){if($stack[0]!=0){$stack[0]=1/$stack[0];}
                                     else{warn "ERROR: can't invert zero.\n";}}}
  elsif($e eq "chs"){if(argsQ($e,1)){$stack[0]=-$stack[0];}}
  elsif($e eq "abs"){if(argsQ($e,1)){$stack[0]=abs($stack[0]);}}
  elsif($e eq "sgn"){if(argsQ($e,1)){$stack[0]=$stack[0]<=>0;}}
  # comparisons
  elsif($e eq "<" ){if(argsQ($e,2)){$x=shift(@stack);
                                    $stack[0]= $x< $stack[0] ? 1:0;}}
  elsif($e eq "<="){if(argsQ($e,2)){$x=shift(@stack);
                                    $stack[0]= $x<=$stack[0] ? 1:0;}}
  elsif($e eq "=="){if(argsQ($e,2)){$x=shift(@stack);
                                    $stack[0]= $x==$stack[0] ? 1:0;}}
  elsif($e eq ">="){if(argsQ($e,2)){$x=shift(@stack);
                                    $stack[0]= $x>=$stack[0] ? 1:0;}}
  elsif($e eq ">" ){if(argsQ($e,2)){$x=shift(@stack);
                                    $stack[0]= $x> $stack[0] ? 1:0;}}
  # powers and roots
  elsif($e eq "sqr" ){if(argsQ($e,1)){$stack[0]**=2;}}
  elsif($e eq "sqrt"){if(argsQ($e,1)){
                        if($stack[0]>=0){$stack[0]=sqrt($stack[0]);}
                        else{warn "ERROR: sqrt($stack[0]) undefined.\n";}}}
  elsif($e eq "pow" ){if(argsQ($e,2)){$x=shift(@stack); $stack[0]**=$x;}}
  elsif($e eq "root"){if(argsQ($e,2)){
                        $x=shift(@stack);
                        if($x!=0){$stack[0]**=(1/$x);}
                        else{warn "ERROR: can't extract a zero-th root.\n";
                             unshift(@stack,$x);}}}
  # number parts
  elsif($e eq "ceil" ){if(argsQ($e,1)){$stack[0]=ceil($stack[0]);}}
  elsif($e eq "floor"){if(argsQ($e,1)){$stack[0]=floor($stack[0]);}}
  elsif($e eq "int"  ){if(argsQ($e,1)){($x,$stack[0])=modf($stack[0]);}}
  elsif($e eq "frac" ){if(argsQ($e,1)){($stack[0],$x)=modf($stack[0]);}}
  elsif($e eq "mod"  ){if(argsQ($e,2)){$x=shift(@stack);
                                       $stack[0]=fmod($stack[0],$x);}}
  # combinatorial functions
  elsif($e eq "fact" ){if(argsQ($e,1)){
                         $x=$stack[0];
                         if($x>=0 && integerQ($x)){$stack[0]=factorial($x);}
                         else{warn "ERROR: fact($x) undefined.\n";}}}
  elsif($e eq "binom"){if(argsQ($e,2)){
                         $x=shift(@stack); $y=$stack[0];
                         if($y>=0 && integerQ($y) && integerQ($x)){
                           $stack[0]=binomial($y,$x);}
                         else{warn "ERROR: binom($y,$x) undefined.\n";
                              unshift(@stack,$x);}}}
  # trigonometric functions
  elsif($e eq "sin"  ){if(argsQ($e,1)){
                         $stack[0]=sin(angle_unit_to_radian($stack[0]));}}
  elsif($e eq "cos"  ){if(argsQ($e,1)){
                         $stack[0]=cos(angle_unit_to_radian($stack[0]));}}
  elsif($e eq "tan"  ){if(argsQ($e,1)){
                         $stack[0]=tan(angle_unit_to_radian($stack[0]));}}
  elsif($e eq "asin" ){if(argsQ($e,1)){
                         if(abs($stack[0])<=1){
                           $stack[0]=radian_to_angle_unit(asin($stack[0]));}
                         else{warn "ERROR: asin($stack[0]) undefined.\n";}}}
  elsif($e eq "acos" ){if(argsQ($e,1)){
                         if(abs($stack[0])<=1){
                           $stack[0]=radian_to_angle_unit(acos($stack[0]));}
                         else{warn "ERROR: acos($stack[0]) undefined.\n";}}}
  elsif($e eq "atan" ){if(argsQ($e,1)){
                         $stack[0]=radian_to_angle_unit(atan($stack[0]));}}
  elsif($e eq "atan2"){if(argsQ($e,2)){
                         $x=shift(@stack);
                         $stack[0]=radian_to_angle_unit(atan2($stack[0],$x));}}
  elsif($e eq "sinc" ){if(argsQ($e,1)){
                         $stack[0]=sinc(angle_unit_to_radian($stack[0]));}}
  elsif($e eq "cosc" ){if(argsQ($e,1)){
                         $stack[0]=cosc(angle_unit_to_radian($stack[0]));}}
  # hyperbolic functions
  elsif($e eq "sinh" ){if(argsQ($e,1)){$stack[0]=sinh($stack[0]);}}
  elsif($e eq "cosh" ){if(argsQ($e,1)){$stack[0]=cosh($stack[0]);}}
  elsif($e eq "tanh" ){if(argsQ($e,1)){$stack[0]=tanh($stack[0]);}}
  elsif($e eq "asinh"){if(argsQ($e,1)){$stack[0]=log($stack[0]+sqrt($stack[0]*$stack[0]+1));}}
  elsif($e eq "acosh"){if(argsQ($e,1)){$stack[0]=log($stack[0]+sqrt($stack[0]*$stack[0]-1));}}
  elsif($e eq "atanh"){if(argsQ($e,1)){$stack[0]=log((1+$stack[0])/(1-$stack[0]))/2;}}
  # exponential and logarithmic functions
  elsif($e eq "ln"   ){if(argsQ($e,1)){
                         if($stack[0]>0){$stack[0]=log($stack[0]);}
                         else{warn "ERROR: ln($stack[0]) undefined.\n";}}}
  elsif($e eq "exp"  ){if(argsQ($e,1)){$stack[0]=exp($stack[0]);}}
  elsif($e eq "log"  ){if(argsQ($e,1)){$stack[0]=log10($stack[0]);}}
  elsif($e eq "alog" ){if(argsQ($e,1)){$stack[0]=10**$stack[0];}}
  elsif($e eq "lg"   ){if(argsQ($e,1)){$stack[0]=log($stack[0])/log(2);}}
  elsif($e eq "alog2"){if(argsQ($e,1)){$stack[0]=2**$stack[0];}}
  elsif($e eq "logb" ){if(argsQ($e,2)){
                         $x=shift(@stack);
                         $stack[0]=log($x)/log($stack[0]);}}
  # special functions
  elsif($e eq "agm"){if(argsQ($e,2)){
                       $x=shift(@stack); $y=$stack[0];
                       if($x>=0 && $y>=0){$stack[0]=agm($x,$y);}
                       else{warn "ERROR: agm($x,$y) undefined.\n";
                            unshift(@stack,$x);}}}
  # mathematical constants
  elsif($e eq "eul"  ){unshift(@stack,$euler_e);}
  elsif($e eq "pi"   ){unshift(@stack,$pi);}
  elsif($e eq "twopi"){unshift(@stack,$twopi);}
  elsif($e eq "gr"   ){unshift(@stack,$golden_ratio);}
  # unit conversions
  elsif($e eq "d2r"  ){if(argsQ($e,1)){$stack[0]/=$deg_per_rad;}}
  elsif($e eq "r2d"  ){if(argsQ($e,1)){$stack[0]*=$deg_per_rad;}}
  elsif($e eq "d2dms"){if(argsQ($e,1)){$stack[0]=d2dms($stack[0]);}}
  elsif($e eq "dms2d"){if(argsQ($e,1)){$stack[0]=dms2d($stack[0]);}}
  elsif($e eq "g2r"  ){if(argsQ($e,1)){$stack[0]=$stack[0]*$pi/200;}}
  elsif($e eq "r2g"  ){if(argsQ($e,1)){$stack[0]=$stack[0]*200/$pi;}}
  elsif($e eq "ev2j" ){if(argsQ($e,1)){
                         if(defined($eq=$cvalues{"elem_charge"})){$stack[0]*=$eq;}
                         else{warn "ERROR: \"elem_charge\" not defined.\n";}}}
  elsif($e eq "j2ev" ){if(argsQ($e,1)){
                         if(defined($eq=$cvalues{"elem_charge"})){$stack[0]/=$eq;}
                         else{warn "ERROR: \"elem_charge\" not defined.\n";}}}
  # functions and variables
  elsif($e eq "clrfns"  ){if($fussy){
                            warn "WARNING: do you wish to clear all functions?\n";
                            print "  "; $a=<STDIN>;
                            if($a=~/^\s*(y|ye|yes)\s*$/){%functions=();}}
                          else{%functions=();}}
  elsif($e eq "clrvar"  ){if($fussy){
                            warn "WARNING: do you wish to clear all variables?\n";
                            print "  "; $a=<STDIN>;
                            if($a=~/^\s*(y|ye|yes)\s*$/){%vars=();}}
                          else{%vars=();}}
  elsif($e eq "readfns" ){print "Enter file name: ";
                          $fname = <>;
                          chomp($fname);
                          init_fns($fname);}
  elsif($e eq "readvars"){print "Enter file name: ";
                          $fname = <>;
                          chomp($fname);
                          init_constants($fname);}
  # stack manipulation
  elsif($e eq "del" ){if(argsQ($e,1)){shift(@stack);}}
  elsif($e eq "clr" ){@stack=();}
  elsif($e eq "swap"){if(argsQ($e,2)){
                        ($stack[0],$stack[1])=($stack[1],$stack[0]);}}
  elsif($e eq "dup" ){if(argsQ($e,1)){unshift(@stack,$stack[0]);}}
  elsif($e eq "dup2"){if(argsQ($e,2)){unshift(@stack,$stack[0],$stack[1]);}}
  elsif($e eq "dupn"){if(argsQ($e,1+$stack[0])){
                        $n=int(shift(@stack));
                        unshift(@stack,@stack[0..$n-1]);}}
  elsif($e eq "fill"){if(argsQ($e,2)){
                        $n=int(shift(@stack));
                        foreach (1..$n-1){unshift(@stack,$stack[0]);}}}
  elsif($e eq "pick"){if(argsQ($e,1+abs($stack[0]))){
                        $n=int(shift(@stack));
                        if($n>0){unshift(@stack,$stack[$n-1]);}
                        elsif($n<0){unshift(@stack,$stack[$#stack+1+$n]);}}}
  elsif($e eq "rot" ){if(defined($x=shift(@stack))){push(@stack,$x);}}
  elsif($e eq "rotd"){if(defined($x=pop(@stack))){unshift(@stack,$x);}}
  elsif($e eq "rotn"){if(argsQ($e,1+abs($stack[0]))){
                        $n=int(shift(@stack));
                        if($n>0){@x=splice(@stack,0,$n);
                                 splice(@stack,$#stack+1,0,@x);}
                        elsif($n<0){@x=splice(@stack,$#stack+1+$n,-$n);
                                    splice(@stack,0,0,@x);}}}
  elsif($e eq "roll"){if(argsQ($e,1+abs($stack[0]))){
                        $n=int(shift(@stack));
                        if($n>0){@x=splice(@stack,0,$n);
                                 $x=shift(@x); push(@x,$x);
                                 splice(@stack,0,0,@x);}
                        elsif($n<0){@x=splice(@stack,0,-$n);
                                    $x=pop(@x); unshift(@x,$x);
                                    splice(@stack,0,0,@x);}}}
  elsif($e eq "rev" ){@stack=reverse(@stack);}
  elsif($e eq "revn"){if(argsQ($e,1+abs($stack[0]))){
                        $n=int(shift(@stack));
                        if($n>0){@x=splice(@stack,0,$n);
                                 splice(@stack,0,0,reverse(@x));}
                        elsif($n<0){warn "ERROR: negative argument $n passed to \"$e\".\n";
                                    unshift(@stack,$n);}}}
  elsif($e eq "stk" ){print_stack($#stack+1);}
  elsif($e eq "stk2"){print_stack(2);}
  elsif($e eq "stkn"){if(argsQ($e,1+abs($stack[0]))){
                        print_stack(int(shift(@stack)));}}
  # modes
  elsif($e eq "deg" ){$angle_unit="degree";    print "Angle unit set to degree.\n"; }
  elsif($e eq "dms" ){$angle_unit="degminsec"; print "Angle unit set to degminsec.\n"; }
  elsif($e eq "rad" ){$angle_unit="radian";    print "Angle unit set to radian.\n"; }
  elsif($e eq "grad"){$angle_unit="gradian";   print "Angle unit set to gradian.\n"; }
  elsif($e eq "std"){if(argsQ($e,1)){
                       $n=shift(@stack);
                       if($n>=1 && $n<=$precision_max){$print_mode="standard";
                                                       $print_precision=int($n);}
                       elsif($n<1){warn "ERROR: argument $n too small for \"$e\".\n";
                                   unshift(@stack,$n);}
                       else{warn "ERROR: argument $n too large for \"$e\".\n";
                            unshift(@stack,$n);}}}
  elsif($e eq "fix"){if(argsQ($e,1)){
                       $n=shift(@stack);
                       if($n>=0 && $n<=$precision_max){$print_mode="fixed";
                                                       $print_precision=int($n);}
                       elsif($n<0){warn "ERROR: argument $n too small for \"$e\".\n";
                                   unshift(@stack,$n);}
                       else{warn "ERROR: argument $n too large for \"$e\".\n";
                            unshift(@stack,$n);}}}
  elsif($e eq "sci"){if(argsQ($e,1)){
                       $n=shift(@stack);
                       if($n>=1 && $n<=$precision_max){$print_mode="scientific";
                                                       $print_precision=int($n);}
                       elsif($n<1){warn "ERROR: argument $n too small for \"$e\".\n";
                                   unshift(@stack,$n);}
                       else{warn "ERROR: argument $n too large for \"$e\".\n";
                            unshift(@stack,$n);}}}
  elsif($e eq "eng"){if(argsQ($e,1)){
                       $n=shift(@stack);
                       if($n>=2 && $n<=$precision_max){$print_mode="engineering";
                                                       $print_precision=int($n);}
                       elsif($n<2){warn "ERROR: argument $n too small for \"$e\".\n";
                                   unshift(@stack,$n);}
                       else{warn "ERROR: argument $n too large for \"$e\".\n";
                            unshift(@stack,$n);}}}
  elsif($e eq "dsp"){if(argsQ($e,1)){
                       $n=shift(@stack);
                       if($n>=1 && $n<=$display_max){$stack_display=int($n);}
                       elsif($n<1){warn "ERROR: argument $n too small for \"$e\".\n";
                                   unshift(@stack,$n);}
                       else{warn "ERROR: argument $n too large for \"$e\".\n";
                            unshift(@stack,$n);}}}
  elsif($e eq "fussy" ){$fussy=1;}
  elsif($e eq "sloppy"){$fussy=0;}
  elsif($e eq "modes" ){RPNmodes();}
  # help
  elsif($e eq "help"  ){RPNhelp();}
  elsif($e eq "??"    ){RPNquick_ref();}
  elsif($e eq "?math" ){RPNmath_ref();}
  elsif($e eq "?trig" ){RPNtrig_ref();}
  elsif($e eq "?exp"  ){RPNexp_ref();}
  elsif($e eq "?const"){RPNconst_ref();}
  elsif($e eq "?conv" ){RPNconv_ref();}
  elsif($e eq "?stack"){RPNstack_ref();}
  elsif($e eq "?modes"){RPNmode_ref();}
  elsif($e eq "?user" ){RPNuser_ref();}
  elsif($e eq "?funcs"){RPNfuncs_ref();}
  elsif($e eq "?vars" ){RPNvars_ref();}
  elsif($e eq "????"  ){RPNbanner(); RPNhelp(); RPNquick_ref();
                        RPNmath_ref(); RPNtrig_ref(); RPNexp_ref();
                        RPNconst_ref(); RPNconv_ref();
                        RPNstack_ref(); RPNmode_ref();
                        RPNuser_ref(); RPNfuncs_ref(); RPNvars_ref();
                        RPNmodes();}
  # end
  elsif($e eq "end"){$RPNterm->stifle_history($MAX_HISTORY);
                     $RPNterm->write_history("$RPN_HISTORY");
                     exit;}
  # not defined
  else{print "Sorry, \"$e\" not yet implemented.\n";}
}

sub print_eng { # print number in form _.___e+/-p, with p a multiple of 3
  my($x)=@_;
  my($pp)=($print_precision);
  my($m,$p,$d);
  if($x!=0){
    $p=int(floor(log10(abs($x))));
    $d=($p%3+3)%3;
    $p-=$d;
    $m=$x/(10**$p);}
  else{$m=$p=$d=0;}
  printf("% *.*fe%+-3d",2+$pp,$pp-$d,$m,$p);
}

sub print_fix {
  my($x)=@_;
  my($pp)=($print_precision);
  printf("% *.*f",16+$pp,$pp,$x);
}

sub print_num {
  my($e)=@_;
     if($print_mode eq "standard"   ){print_std($e);}
  elsif($print_mode eq "fixed"      ){print_fix($e);}
  elsif($print_mode eq "scientific" ){print_sci($e);}
  elsif($print_mode eq "engineering"){print_eng($e);}
}

sub print_sci {
  my($x)=@_;
  my($pp)=($print_precision);
  printf("% *.*e", 8+$pp,$pp,$x);
}

sub print_stack {
  my($k,$l);
  $l = $#stack+1>=$_[0] ? $_[0]-1 : $#stack ;
  print "\n";
  foreach $k (reverse(0..$l)) {
    printf("%2d: ",$k+1); print_num($stack[$k]); print("\n");}
  print "\n";
}

sub print_std {
  my($x)=@_;
  my($pp)=($print_precision);
  printf("% *.*g", 9+$pp,$pp,$x);
}

sub radian_to_angle_unit{
  my($ang)=@_;
  if($angle_unit eq "radian"){return $ang;}
  if($angle_unit eq "gradian"){return $ang*200/$pi;}
  if($angle_unit eq "degree"){return $ang*$deg_per_rad;}
  if($angle_unit eq "degminsec"){return d2dms($ang*$deg_per_rad);}
}

sub RPNbanner { print "
  *************************************************
  **  RPN: a Reverse Polish Notation calculator  **
  **               for help: type 'help' or '?'  **
  *************************************************

";
}

sub RPNconst_ref {
  $~ ="CONSTANTS";
  print "
           == Defined Constants ==
  e                      : base of the natural logarithm
  pi                     : circumference/diameter of any circle
  twopi                  : 2 * pi
  gr golden_ratio        : golden ratio = (1 + sqrt(5)) / 2

";
  foreach $cname (sort keys %cvalues) { write; }
}

format CONSTANTS =
  @<<<<<<<<<<<<<<<<<<<<< : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  $cabbrevs{$cname},       $cdescr{$cname}
.

sub RPNconv_ref { print "
   == Unit Conversion Functions ==
  d2r         : degrees to radians (1)
  r2d         : radians to degrees (1)
  d2dms,h2hms : degrees(hours) to degrees(hours)-minutes-seconds (1)
  dms2d,hms2h : degrees(hours)-minutes-seconds to degrees(hours) (1)
  g2r         : gradians to radians (1)
  r2g         : radians to gradians (1)

  ev2j,eV2J : electron-volts to Joules (1)
  j2ev,J2eV : Joules to electron-volts (1)

";
}

sub RPNexp_ref { print "
   == Exponential and Logarithmic Functions ==
  ln          : natural logarithm (1)
  exp,ex,aln  : exponential function, e^x (1)
  log,log10   : base 10 logarithm (1)
  alog,dxp,tx : anti-logarithm, 10^x (1)
  lg,log2     : base 2 logarithm (1)
  alog2,twox  : base 2 anti-logarithm, 2^x (1)
  logb        : base b logarithm, log_y(x) (2)

";
}

sub RPNfuncs_ref {
#  $Text::Wrap::columns=42;
  if(%functions==()){print "\n   == No Functions Defined ==\n"; return;}
  print "\n   == Defined Functions ==\n";
  foreach $fn (sort keys %functions) {
    printf(" %-16s : ",$fn);
    print wrap("","                  : ",$functions{$fn});
    print("\n\n");
  }
}

sub RPNhelp { print "
   == RPN Help ==
  This calculator uses Reverse Polish Notation (RPN). As an example,
  the expression 2*(3+4) takes the form
          3 4 + 2 *
  in RPN. The essential idea here is that one supplies the operands
  first, the operator afterwards. (These elements may be entered on
  one or several lines.)

  For information on the various \"buttons\" and features provided by
  this calculator, use one of the following help commands:
     '?math' : basic arithmetic functions
     '?trig' : trigonometric and hyperbolic  functions
     '?hyp'  : == '?trig'
     '?exp'  : exponential and logarithmic functions
     '?log'  : == '?exp'
     '?const': defined constants
     '?conv' : unit conversions
     '?stack': stack operations
     '?modes': mode settings
     '?user' : defining new functions and variables
     '?funcs': defined functions
     '?fns'  : == '?funcs'
     '?vars' : defined variables

  Also, '??' produces a \"quick-reference\" guide to all the \"buttons\"
  available on this calculator.

";
}

sub RPNmath_ref { print "
   == Basic Math Operations ==
  +  : addition (2)*
  -  : subtraction (2)
  *  : multiplication (2)
  /  : division (2)
  ++ : increment (1)
  -- : decrement (1)

  +++ : pythagorean addition (2)
  +-+ : pythagorean subtraction (2)

  tm+,t+ : time (angle) addition (2)
  tm-,t- : time (angle) subtraction (2)

  <  : less than (1)
  <= : less than or equal (1)
  == : equal (1)
  >= : greater than or equal (1)
  >  : greater than (1)

  inv       : inverse, or reciprocal, 1/x (1)
  chs,neg,n : change sign, or negation, -x (1)
  abs       : absolute value, |x| (1)
  sgn,sign  : 1, 0, or -1 if x>0, x==0, or x<0 (1)

  sqr,sq   : square, x^2 (1)
  sqrt     : square root (1)
  pow,**,^ : power, y^x (2)
  root,rt  : root, y^(1/x) (2)

  ceil,ceiling : smallest integer >= x (1)
  floor,flr    : largest integer <= x (1)
  int          : integer part of x (1)
  frac         : fractional part of x (1)
  mod,|        : modulo, y mod x (2)

  fact,fct,!       : factorial, x! (1)
  binom,bin,choose : binomial coefficient, y choose x (2)
  agm              : agm (2), arithmetic-geometric mean

  *Shown in parentheses for each \"button\" is the number of arguments
   (if any) required from the stack. Also, 'x' refers to the most
   recent entry in the stack, while 'y' refers to the following stack
   entry.

";
}

sub RPNmode_ref { print "
   == Calculator Modes ==
  deg  : degree mode
  dms  : degrees-minutes-seconds mode
  rad  : radian mode
  grad : gradian mode

  std : standard notation (1)
  fix : fixed-point notation (1)
  sci : scientfic notation (1)
  eng : engineering notation (1)

  dsp,display : set display length (1)
  fussy       : ask before overwriting or clearing varables and functions
  sloppy      : overwrite varables and functions silently
  modes       : display current mode settings

";
}

sub RPNmodes { print "
   == Present Mode Settings ==
  angle unit      $angle_unit
  print mode      $print_mode
  print precision $print_precision
  display size    $stack_display
  behavior        ";
  if($fussy){print "fussy\n\n";}
  else{print "sloppy\n\n";}
}

sub RPNquick_ref { print "
   == RPN Quick-Reference Guide ==
  This RPN calculator has the following \"buttons\" (in CAPS); and next
  to each \"button\" are listed its associated abbreviations.

  ADD : +   LT: <   INV : inv        SQR : sqr,sq    CEIL : ceil,ceiling
  SUB : -   LE: <=  CHS : chs,neg,n  SQRT: sqrt      FLOOR: floor,flr
  MUL : *   EQ: ==  ABS : abs        POW : pow,**,^  INT  : int
  DIV : /   GE: >=  SGN : sgn,sign   ROOT: root,rt   FRAC : frac
  INCR: ++  GT: >   PADD: +++        TADD: tm+,t+    MOD  : mod,|
  DECR: --          PSUB: +-+        TSUB: tm-,t-

  FACT : fact,fct,!
  BINOM: binom,bin,choose
  AGM:   agm

  SIN : sin    ASIN : asin,arcsin     LN   : ln
  COS : cos    ACOS : acos,arccos     EXP  : exp,ex,aln
  TAN : tan    ATAN : atan,arctan     LOG  : log,log10
  SINC: sinc   ATAN2: atan2,arctan2   ALOG : alog,dxp,tx
  SINH: sinh   ASINH: asinh,arcsinh   LG   : lg,log2
  COSH: cosh   ACOSH: acosh,arccosh   ALOG2: alog2,twox
  TANH: tanh   ATANH: atanh,arctanh   LOGB : logb
  COSC: cosc

  E : e   PI: pi   TWOPI: twopi   GR: gr,golden_ratio

  D2R  : d2r           G2R: g2r   EV2J: ev2j,eV2J
  R2D  : r2d           R2G: r2g   J2eV: j2ev,J2eV
  D2DMS: d2dms,h2hms
  DMS2D: dms2d,hms2h

  DEL : del,x       PICK: pick,pk    STK : stk,stack,show,sh,ls
  CLR : clr,clear   ROT : rot,rr     STK2: stk2,stack2,show2,sh2,ls2
  SWAP: swap,sw,s   ROTD: rotd,rd    STKN: stkn,stackn,lsn
  DUP : dup,d       ROTN: rotn,rrn   UNDO: undo
  DUP2: dup2,d2     ROLL: roll
  DUPN: dupn,dn     REV : rev
  FILL: fill        REVN: revn

  DEG : deg   STD: std   SCI: sci   DSP: dsp,display   FUSSY : fussy
  DMS : dms   FIX: fix   ENG: eng                      SLOPPY: sloppy
  RAD : rad                                            MODES : modes
  GRAD: grad

  HELP : help,?   TRG_H: ?trig,?hyp   CNV_H: ?conv    USR_H: ?user
  Q_REF: ??       EXP_H: ?exp,?log    STK_H: ?stack   FNS_H: ?funcs,?fns
  MTH_H: ?math    CNS_H: ?const       MOD_H: ?modes   VAR_H: ?vars

  READFNS: readfns   CLRFNS: clrfns
  READVAR: readvar   CLRVAR: clrvar

  END: end,exit,quit,bye

  You may enter numbers in either C or Fortran form, and you may append
  to a number any of the standard SI prefixes:
    Y, Z, E, P, T, G, M, k (or K), h, da, d, c, m, u, n, p, f, a, z, y.
  You may also enter times (equivalently angles) in any of the forms
  hhh:mm:ss(.sss), hhh:mm, or mm:ss.(sss). Note that RPN automatically
  converts time (or angle) data entered in one of these forms to the
  form hhh.mmsssss (or ddd.mmsssss).

";
}

sub RPNstack_ref { print "
   == Stack Operations ==
  This calculator uses a stack which changes size as needed by the user.
  By convention, the \"last\" element on the stack means the last element
  placed on the stack. This element is, of course, also the first
  element that will be retrieved from the stack.

  del,x     : delete the last entry in the stack (1)
  clr,clear : delete all stack entries
  swap,sw,s : swap, or switch, the last two stack entries (2)
  dup,d     : duplicate the last entry in the stack (1)
  dup2,d2   : duplicate the last two entries in the stack (2)
  dupn,dn   : duplicate the last 'n' entries in the stack (1+n)
  fill      : fill the stack with 'n' copies of its most recent entry (2)
  pick,pk   : copy the stack's n-th entry (1+abs(n))
  rot,rr    : rotate the entire stack
            : (the last entry becomes the least accessible)
  rotd,rd   : rotate the stack the other way
  rotn,rrn  : rotate the stack 'n' times (1+abs(n))
            : (use '-n' to rotate in the opposite sense)
  roll      : rotate the last 'n' stack entries (1+abs(n))
            : (use '-n' to rotate in the opposite sense)
  rev       : reverse the order of all entries in the stack
  revn      : reverse the order of the last 'n' entries in the stack

  stk,stack,show,sh,ls      : show the entire stack
  stk2,stack2,show2,sh2,ls2 : show stack's last two entries
  stkn,stackn,lsn           : show stack's last 'n' entries (1+abs(n))

  undo : restore the stack to its previous state

";
}

sub RPNtrig_ref { print "
   == Trigonometric and Hyperbolic Functions ==
  sin           : sine (1)
  cos           : cosine (1)
  tan           : tangent (1)
  sinc          : sinc (1)
  asin,arcsin   : inverse sine (1)
  acos,arccos   : inverse cosine (1)
  atan,arctan   : inverse tangent (1)
  atan2,arctan2 : inverse tangent, atan2(y,x), taking into account
                :   which quadrant contains the point (x,y) (2)
  sinh          : hyperbolic sine (1)
  cosh          : hyperbolic cosine (1)
  tanh          : hyperbolic tangent (1)
  asinh,arcsinh : inverse hyperbolic sine (1)
  acosh,arccosh : inverse hyperbolic cosine (1)
  atanh,arctanh : inverse hyperbolic tangent (1)
  cosc          : cosc (1), (1 - cos(x)) / x^2

  Note: For the trigonometric functions, angles may be given in units of
  decimal degrees, degrees-minutes-seconds, radians, or gradians.
  (100 gradians = 90 degrees.) Use the mode settings, see \"?modes\",
  to set the desired angular unit; see \"?conv\" for unit conversions.

";
}

sub RPNuser_ref { print "
   == Defining Functions and Variables ==
  To define a variable, precede the variable name with a single quote,
  or surround it with a pair of quotes (no spaces). For example, either
          1.23 'r
  or
          1.23 'r'
  will store the value 1.23 in a variable named 'r'. To use a variable,
  simply give its name. Thus
          r
  will enter its value---here 1.23---onto the stack.

  To define a function, precede its definition with \":fn:\", and follow
  its definition with \": fname\", where \"fname\" is the name of the
  function. You may end any line with a comment as \"# commnt\". This
  may be done on one or several lines, but the definition MUST BEGIN ON
  A NEW LINE. Thus either
          :fn: sqr pi * :circ  # r circ ==> area
  or
          :fn: # r circ ==> area
          sqr pi * :circ
  defines a function circ that computes circular areas.

  To remove any function or variable, precede its name with a left
  parenthesis, or surround its name with a pair of parentheses. Thus,
  for example, either
          (r
  or
          (r)
  will delete the variable 'r'. You can simultaneously remove several
  items by separating their names with commas, no spaces:
          (r,circ
  will delete both 'r' and 'circ'.

  clrfns  : delete all user-defined functions
  clrvar  : delete all user-defined variables
  readfns : read a set of user-defined functions from a file
  readvar : read a set of user-defined variables from a file

  To review defined functions or variables, use one of
  the following commands:
     '?funcs': defined functions
     '?fns'  : == '?funcs'
     '?vars' : defined variables

  NB: One may begin a function definition by storing stack entries as
  variables, and then end the definition by deleting those variables.
  A useful convention is to give those 'local' variables a name that
  begins with the underscore '_'. One may NOT, however, use this
  aproach to define recursive functions. At the moment, a recursive
  function must rely on the stack alone.

";
}

sub RPNvars_ref {
  if(%vars==()){print "\n   == No Variables Defined ==\n"; return;}
  print "\n    == Defined Variables ==\n";
  foreach $var (sort keys %vars) {
    printf(" %12s : ",$var); print_num($vars{$var}); print("\n");}
}

sub rpn_parse {
  my($line)=@_;
  $line=~s/\s*\#.*$//;
  my(@elems)=split(" ",$line);
  my(@temp)=@stack;
  foreach $e (@elems){
    if(numberQ($e)){unshift(@stack,$e+0);}
    elsif(sinumQ($e)){unshift(@stack,$e+0);}
    elsif(timeQ($e)){unshift(@stack,$e+0);}
    elsif(defined($op=$ops{$e})){operation($op);}
    elsif(defined($cname=$cnames{$e})){unshift(@stack,$cvalues{$cname});}
    elsif(defined($var=$vars{$e})){unshift(@stack,$var);}
    elsif(defined($fn=$functions{$e})){rpn_function($fn);}
    elsif(var_defQ($e)){var_def($e);}
    elsif(name_rmvQ($e)){name_rmv($e);}
    else{warn "ERROR: input \"$e\" not recognized.\n";
         @stack=@temp;
         return("error");}
  }
  @old_stack=@temp;
  return($ops{$elems[-1]});
}

sub rpn_function {
  my($code)=@_;
  my(@lines)=split(/\n/,$code);
  my(@temp)=@stack;
  my($f);
  foreach $line (@lines){$f=rpn_parse($line);
                         if($f eq "error"){last;}}
  @old_stack=@temp;
}

sub sinc {  # double precision sin(x)/x
  my($ang)=@_;
  my($ang2);
  if(abs($ang)>=0.04){return(sin($ang)/$ang);}
  else{$ang2=$ang*$ang;
       return(1.-$ang2/6.*(1-$ang2/20.*(1-$ang2/42.)));}
}

sub sinumQ {
  if($_[0] =~ /^(.*\d+.*)(da)$/ ||
     $_[0] =~ /^(.*\d+.*)(Y|Z|E|P|T|G|M|k|K|h|d|c|m|u|n|p|f|a|z|y)$/){
    my ($n,$s)=($1,$2);
    if(numberQ($n)){
      $_[0]=$n*$SI{$s};
      return 1;
    }
  }
  return 0;
}

sub switch_stacks {  # interchange @stack and @old_stack
  my(@temp);
  @temp=@stack; @stack=@old_stack; @old_stack=@temp;
}

sub timeQ {
     if($_[0] =~ /^(\d+):([0-5]\d):([0-5]\d)\.(\d*)$/){ # hhh:mm:ss(.sss)
        $_[0] = join('',$1,'.',$2,$3,$4);
        return 1;}
  elsif($_[0] =~ /^(\d+):([0-5]\d):([0-5]\d)$/){        # hhh:mm:ss
        $_[0] = join('',$1,'.',$2,$3);
        return 1;}
  elsif($_[0] =~ /^(\d+):([0-5]\d)$/){                  # hhh:mm
        $_[0] = join('',$1,'.',$2);
        return 1;}
  elsif($_[0] =~ /^([0-5]\d):([0-5]\d)\.(\d*)$/){       # mm:ss.(sss)
        $_[0] = join('','0.',$1,$2,$3);
        return 1;}
  elsif($_[0] =~ /^(\d):([0-5]\d)\.(\d*)$/){            # m:ss.(sss)
        $_[0] = join('','0.0',$1,$2,$3);
        return 1;
  } else {return 0;}
}

sub var_def {
  my($vname)=@_;
  $vname=~s/\'//g;
  if(argsQ("'".$vname,1)){
    $vname=get_name($vname);
    $vars{$vname}=shift(@stack);
  }
}

sub var_defQ {
  return($_[0] =~ /^\'\w*\'?$/);
}

