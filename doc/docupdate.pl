#!/usr/bin/perl


use Text::Wrap;

#
# @(#) Read all files and group the functions by objects
#

my $M_doc = 'endurox-go-book.adoc';

#
# So we will store Object.Func.
#
my %M_func = ();


#
# Support funcs
#

sub read_file {
    my ($filename) = @_;
 
    open my $in, '<:encoding(UTF-8)', $filename or die "Could not open '$filename' for reading $!";
    local $/ = undef;
    my $all = <$in>;
    close $in;
 
    return $all;
}
 
sub write_file {
    my ($filename, $content) = @_;
 
    open my $out, '>:encoding(UTF-8)', $filename or die "Could not open '$filename' for writing $!";;
    print $out $content;
    close $out;
 
    return;
}


$Text::Wrap::columns = 80;

foreach my $file (@ARGV)
{
	open my $fh, '<', $file or die $!;

	my $lines = "";
	my $was_comment = 0;
	my $was_func_start = 0;
NEXT:	while (<$fh>) {
		# line contents's automatically stored in the $_ variable
		#print $_;
		chomp;
		
		my $line = $_;
		
		#print $line ;
		if ($line =~/^\/\//)
		{
			# Strip off the comment
			$line = substr $line, 2;
			$was_comment = 1;
			$lines = $lines.' '.$line;
		}
		elsif($line =~/^func/)
		{
		
			my $func = "";
			my $struct = "atmi";
			my $return = "";
			my $def = "";
			
			if ($line=~/^func.*[^\{]\s*$/)
			{
				# We need to read some more lines here and join them
				# util we get the scope open symbol
				while (<$fh>)
				{
					chomp;
					if ($line =~/^func.*[^\{]\s*$/)
					{
						last;
					}
					$line = $line.$_;
				}
			}
			# Ok This is our func, get the structure or it is global/atmi.
			
			# func (ac *ATMICtx) TpACall(svc string, tb TypedBuffer, flags int64) ATMIError {
			
			print "got [$line]\n";
			($def) = ($line =~ /(.*)\s\{/);
			
			print "func definition [$def]\n";
			
			
			if ($line =~/^func\s*\(.*\)\s*[A-Za-z0-9_]*\(.*\)\s*\(.*\)\s*{/)
			{
				# func (ac *ATMICtx) TpACall(svc string, tb TypedBuffer, flags int64) (int, ATMIError) {
				print "1: [$line]\n";
				($struct, $func, $return) = ($line =~/^func\s*\(.*\s\**(.*)\)\s*([A-Za-z0-9_]*)\(.*\)\s*\((.*)\)\s*{/);
			}
			elsif ($line =~/^func\s*\(.*\)\s*[A-Za-z0-9_]*\(.*\)\s*[0-9A-Za-z_\*]*\s*{/)
			{
				# func (ac *ATMICtx) TpACall(svc string, tb TypedBuffer, flags int64)  ATMIError {
				print "2: [$line]\n";
				($struct, $func, $return) = ($line =~/^func\s*\(.*\s\**(.*)\)\s*([A-Za-z0-9_]*)\(.*\)\s*([0-9A-Za-z_\*]*)\s*{/);
			}
			elsif ($line =~/^func\s*[A-Za-z0-9_]*\(.*\)\s*\([0-9A-Za-z_]*\)\s*{/)
			{
				# func NewATMICtx() (*ATMICtx, ATMIError) {
				print "3: [$line]\n";
			}
			elsif ($line =~/^func\s*[A-Za-z0-9_]*\(.*\)\s*[A-Za-z0-9_\*]*s*{/)
			{
				# func NewATMICtx() ATMIError {
				print "4: [$line]\n";
			}
			
			print "func: [$func]\n";
			print "struct: [$struct]\n";
			print "return: [$return]\n";
			
			if ($func!~/^[A-Z]/)
			{
				print "Func does not start with capital\n";
				next NEXT;
			}
			print "Building doc...\n";
			
			my @fields = split /@/, $lines;
			
			my $descr = $fields[0];
			my $retdescr = "";
			my $varname = "";
			my $vardescr = "";
			
			$descr =~ s/^\s+|\s+$//g;
			
			$descr = "$descr. ";
			#my $have_params = 0;
			
			for (my $i=1; $i < scalar @fields; $i++) {
				
				if ($fields[$i]=~/^param/)
				{
					($varname, $vardescr) = ($fields[$i] =~ /^param\s*([^\s]*)\s*(.*)\s*/);
					
					$varname =~ s/^\s+|\s+$//g;
					$vardescr =~ s/^\s+|\s+$//g;
					
					$descr = $descr."\n*$varname* $vardescr. ";
				}
				elsif ($fields[$i]=~/^return/)
				{
					($retdescr) = ($fields[$i] =~ /^return\s*(.*)\s*/);
					
					$retdescr =~ s/^\s+|\s+$//g;
				}
			}
			
			
			my $final_block = "";
			my $server_block = "";
			
			if ($file=~/atmisrv.go/)
			{
				$server_block="To XATMI server";
			}
			else
			{
				$server_block="XATMI client and server";
			}
			
			if ($retdescr eq "")
			{
				$final_block = <<"END_MESSAGE";
[cols="h,5a"]
|===
| Function
| $def
| Description
| $descr
| Applies
| $server_block
|===

END_MESSAGE
			}
			else
			{
				$final_block = <<"END_MESSAGE";
[cols="h,5a"]
|===
| Function
| $def
| Description
| $descr
| Returns
| $retdescr
| Applies
| $server_block
|===

END_MESSAGE
			}
			$final_block = wrap('', '', $final_block);
			
			print "***************GENERATED DOC ****************\n";
			print "$final_block\n";
			print "*********************************************\n";
			
			# Link to the key
			$M_func{"$struct\.$func"} = $final_block;
		}
		else
		{
			$was_comment = 0;
			$lines = "";
		}
	
	}
	close $fh or die $!;

}

### OK Seems like we got the stuff out, now need to sort and plot the doc
# https://perlmaven.com/how-to-sort-a-hash-in-perl


my $topic = "";

my $output = "";

foreach my $name (sort { $M_func{$a} <=> $M_func{$b} or $a cmp $b } keys %M_func)
{

	printf "SORTED: %-8s %s\n", $name, $M_func{$name};

	if ($name=~/^atmi\./ && $topic ne "atmi")
	{
		$topic = "atmi";
		$output = $output."=== ATMI Package functions\n";
	}
	elsif ($name=~/^nstdError\./ && $topic ne "nstdError")
	{
		$topic = "nstdError";
		$output = $output."=== Enduro/X Standard Error Object / NSTDError interface\n";
	}
	elsif ($name=~/^TypedJSON\./ && $topic ne "TypedJSON")
	{
		$topic = "TypedJSON";
		$output = $output."=== JSON IPC buffer format\n";
	}
	elsif ($name=~/^TypedString\./ && $topic ne "TypedString")
	{
		$topic = "TypedString";
		$output = $output."=== String IPC buffer format\n";
	}
	elsif ($name=~/^TypedUBF\./ && $topic ne "TypedUBF")
	{
		$topic = "TypedUBF";
		$output = $output."=== UBF Key/value IPC buffer format\n";
	}
	elsif ($name=~/^TypedCarray\./ && $topic ne "TypedCarray")
	{
		$topic = "TypedCarray";
		$output = $output."=== Binary buffer IPC buffer format\n";
	}
	elsif ($name=~/^ATMIBuf\./ && $topic ne "ATMIBuf")
	{
		$topic = "ATMIBuf";
		$output = $output."=== Abstract IPC buffer - ATMIUbf\n";
	}
	elsif ($name=~/^ATMICtx\./ && $topic ne "ATMICtx")
	{
		$topic = "ATMICtx";
		$output = $output."=== ATMI Context\n";
		$output = $output."This concentrates most of the ATMI Enduro/X functionality. And is able to run multiple contexts in Go routines\n";
	}
	elsif ($name=~/^atmiError\./ && $topic ne "atmiError")
	{
		$topic = "atmiError";
		$output = $output."=== ATMI Error object / ATMIError interface\n";
	}
	elsif ($name=~/^ubfError\./ && $topic ne "ubfError")
	{
		$topic = "ubfError";
		$output = $output."=== BUF Error object/ UBFError interface\n";
	}
	
	
	# Have title for function
	
	#my ($funcname) = ($name =~ /^.*\.(.*)/);
	
	$output = $output."==== $name()\n";
	
	
	$output = $output.$M_func{$name}."\n";
    
}

print $output;


#
# Got to replace text between two anchors..
#
if (-e $M_doc)
{
	my $data = read_file($M_doc);
	#$data =~ s/Copyright Start-Up/Copyright Large Corporation/g;
	
	$data =~ s/(\[\[gen_doc-start\]\]\n)(.+?)(\[\[gen_doc-stop\]\]\n)/$1$output$2/s;
	
	write_file($M_doc, $data);
	exit;
}
else
{
	print STDERR "$M_doc does not exists in current directory!\n";
	exit -1
}



