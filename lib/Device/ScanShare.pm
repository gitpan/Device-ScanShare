package Device::ScanShare;
use File::Slurp;
use File::Path;
use strict;
use Carp;
our $VERSION = sprintf "%d.%03d", q$Revision: 1.4 $ =~ /(\d+)/g;

sub new {
	my ($class, $self ) = (shift, shift);
	$self ||= {};

	$self->{userdirs_abs_path} or croak('missing "userdirs_abs_path" argument to constructor- you must specify userdirs_abs_path, absolute path to USERDIRS file');
	
	bless $self, $class;

	$self->{base_path} = $self->{userdirs_abs_path};
	$self->{base_path}=~s/\/[^\/]+txt$//i or die($!." cant etablish basepath");
		
	return $self;
}






sub user_delete {
	my ($self, $windowspath) = (shift, shift);
	$windowspath or croak("missing path argument for entry to remove in user_delete_by_path()");
	$windowspath=~s/\//\\/g;

	my $unixpath = $windowspath;
	$unixpath=~s/\\/\//g;	

	exists $self->_data->{$windowspath} or return;		
	delete $self->_data->{$windowspath};  

	#rmdir($self->{base_path}."/$unixpath") or print STDERR "removed $windowspath from USERDIRS.TXT but could not delete directory ($$self{base_path}$/unixpath) because it is not empty? $!";

	$self->save;
	return 1;
}



sub get_user { 
	my ($self,$windowspath) = (shift,shift);
	$windowspath=~s/\//\\/g;	
	return $self->_data->{$windowspath};
}


sub user_add {
	my ($self, $argv) = (shift, shift);

	$argv->{ label } || croak('provide label for this new entry - user_add()');
	$argv->{ path } || croak('provide path to this entry - user_add()'); # this is coming in windows\like
	$argv->{ host } ||= $self->{default_host};

	my $unixpath = $argv->{path};
	my $windowspath = $argv->{path};

	$windowspath=~s/\//\\/g;
	$unixpath=~s/\\/\//g; # we need to convert so that if
		# path/is/here
		# path\is\here 
		# either way we get the unix/path and the windows\path


	if( exists $self->_data->{$windowspath}){ print STDERR "path $windowspath is already in USERDIRS.TXT" and  return 0; } 	
	### user exists



	unless( -d "$$self{base_path}/$unixpath"){
		File::Path::mkpath("$$self{base_path}/$unixpath") or die($!." cannot create $$self{base_path}/$unixpath for user_add() ");
		print STDERR "note $$self{base_path}/$unixpath did not exist and was created";	
	}

	$self->_data->{$windowspath} = {
		label	=>	$argv->{label},
		path	=>	$windowspath,
	};	

	$self->save;
	return 1;
}


sub save {
	my $self = shift;
	# must re sort by label on save only, entry could have been made that needs new sorting


	#reset id, count
	$self->{id} =0;



	#start output, get the header
	my $savefile = $self->_get_header; # start with that

	# has to turn them into line numbers etc 	
	for (@{$self->get_users}){
		$savefile.= $self->_hash_to_line($_)."\n";
	}
	
	open (SVF, "> ".$self->userdirs_abs_path.".tmp") or die("$!, cannot open file for writing: ".$self->userdirs_abs_path);
	print SVF $savefile."\n";
	close SVF;	
	
	rename($self->userdirs_abs_path.'.tmp', $self->userdirs_abs_path) or die("$!, cannot rename"); 
	
	return 1;
}


sub create {
	my $self = shift;

	if ( -f $self->userdirs_abs_path ){
		carp('create() will not proceed, file already exists:'.$self->userdirs_abs_path);
		return 0;	
	}
	return 1 if $self->save;
	
	carp('create() could not save new USERDIRS file');
	return 0;	
}




sub get_users {
	my $self = shift;

	my @records = ();

	for ( sort { $self->_data->{$a}->{label} cmp $self->_data->{$b}->{label} } keys %{$self->_data} ){
		my $hash = $self->get_user($_);		
		push @records, $hash;		
	}
	
	#notes.. why not do this in _read? beacuse if you do and then make changes, they won't show up.

	return \@records;
}


sub count {
	my $self = shift;
	my $count = scalar keys %{$self->_data} ;
	$count ||=0;
	return $count;
}


sub exists {
	my $self = shift;
	-f $self->userdirs_abs_path or return 0;
	return 1;	
}


sub userdirs_abs_path {
	my $self = shift;
	$self->{userdirs_abs_path} or croak('argument userdirs_abs_path missing');
	return $self->{userdirs_abs_path};
}




















# private methods....

sub _hash_to_line { 
  my ($self, $hash) = (shift, shift);
  $self->{id} ||= 0; # init  id marker to save each entry line if it has no value.



  $hash->{path}=~s/\//\\/g; # make into windowspath just in case it's not

  $self->{id}++; # increment id
  $hash->{host} ||= $self->{default_host};
  $hash->{end} ||= 0;	
	my $line = $hash->{label}.'='
		.$hash->{path}.','.$hash->{label}.','
		.$hash->{host}.','.$self->{id}
		.','.$hash->{end};

	return $line;
} 

sub _original_line_to_hash {
	my $line = shift;
	$line=~s/^\s+|\s+$//g;
	my $hash = {};

	$line=~s/^([^=]+)=// or die($line ." seems imporperly formatted?");
	$hash->{label} = $1;
	
	my @vals = split(/,/, $line);
	$hash->{path} = $vals[0];
	$hash->{label2} = $vals[1];
	$hash->{host} = $vals[2];
	$hash->{id} = $vals[3];
	$hash->{end} = $vals[4];

	return $hash;
}






# this is ONLY called when we are saving
# to auto generate the next id count, etc
sub _get_header { 
	my $self = shift;
	
	my $nextid = ( $self->count +1);	
	
	my $out=	 "[PreferredServer]\n"
				."Server=$$self{server}\n"
				."[RoutingID]\n"
				."NextID=$nextid\n"
				."[Users]\n";
	return $out;
}	



sub _data {
	my $self = shift;
	
	unless( defined $self->{data} ){

		if( !$self->exists ){
			carp __PACKAGE__." userdirs does not exist ". $self->userdirs_abs_path.'. ';
			return {};
		}
	
		# we just want the users from this, not header stuff
		my @lines = grep { $self->_is_user_line($_); } File::Slurp::read_file($self->userdirs_abs_path); 

		scalar @lines or print STDERR __PACKAGE__." _read() note: ".$self->userdirs_abs_path." seems empty\n";

		my $data = {};	

		map {
			my $hash = _original_line_to_hash($_);
			$data->{ $hash->{path} } = $hash;		
		} @lines;
	
	
		$self->{data} = $data;	
	}
	return $self->{data};
}


sub _is_user_line {
	my $self = shift;
	my $line = shift;
	#hack to get "Server" from file
	if ($line=~/^Server\=([\d\.\w]+)$/i ){
		$self->{server} = $1;
		return 0;
	}	
	if ( $line =~/^\[\w+\]|^NextID=/i){ return 0; }	
	$line=~/^[^\[\]\/\\=]+=/ or return 0;
	return 1;	
}




1;

__END__

=pod

=head1 NAME

Device::ScanShare - manage USERDIRTS.TXT ecopy file to manage scanner device options

=head1 SYNOPSYS
	
	use Device::ScanShare;

	my $scanshare = new Device::ScanShare({
		userdirs_abs_path => '/var/www/Content/USERDIRS.TXT', 
			# therefore all paths saved are /var/www/Content/$PATH
		server => '192.168.0.150',	
		default_host => 'Dyer05',		
	});

	$scanshare->user_add({
		label=>'Martin', 
		path=>'/home/martin/incoming',
	});

	$scanshare->save;


=head1 WHY

We use ecopy and sharescan software in the office. This is so someone can step up to the scanner and scan to a
predetermined place. They have a little touchscreen.. you punch in where you want to send it to, the name of the file, 
and voila. 
What you can select from is controlled via a file called USERDIRS.TXT. In it are entries like 

	The Label=relative\dir\path,The Label,HostName,1,0

You can edit the damn thing in a text editor. If you have a jillion entries (like we have, upwards of 500), 
then you do not want to micro manage this by either using their crippled interface or via a text editor. Linux
and perl to the rescue. 

Included is also a utility called sharescan that will let you edit the file via the command line.

=head1 DESCRIPTION

ScanShare is a oo module to work with the USERDIRS.TXT file used by ecopy for use with their ShareScan software.
This enables you to control what the entries are via perl. 
You can add and remove entries to the file.
	
=head1 PUBLIC METHODS

=head2 new()

constructor, initiates object.
takes as argument the path to the userdirs file,
the server ip as per USERDIRS.TXT, and the host for each line (Dyer05)

	my $scanshare = new Device::ScanShare({
		userdirs_abs_path => '/var/www/Content/USERDIRS.TXT',
		server => '192.168.0.150',	
		default_host => 'Dyer05',
	});

=head2 create()

will create a new USERDIRS.TXT file in the argument provided to the constructor.
That is, if you want to create a new file:

	my $s = new Device::ScanShare({
		userdirs_abs_path => cwd().'/t/USERDIRS.txt',
		server => '192.168.0.150',
		default_host => 'Dyer05',
	});

	$s->create;

create() will return true or false, will carp if file already exists or if create is not
successful.

=head2 exists()

returns boolean, 
checks if userdirs file exists already or not in the argument provided.

=head2 get_users()

Returns array ref with hashes of data for each userdirs entry- if you have made any additions or removals, this is
reflected. Results are orderded by label.

This method is also used internally to save.

	my @all = $scanshare->get_users();

=cut	



=head1 user_add() and user_delete()

Please note user_add() and user_delete() will save changes to the file.


=head2 user_add()

insert new userdir into records, takes arguments label, and absolute path.
returns 0 if it already exists (by path), returns 1 on success.

	my $path = '/path/to/dirx';
	my $label = 'a new scan destination';
	
	$scanshare->user_add({ label=>$label, path=>$path }) 
		or die("entry already existed for the destination $path");

please note t		

=head2 user_delete()

delete user record, takes absolute path to directory that it saves to as argument

	$scanshare->user_delete('/path/to/target_directory');
	$scanshare->save(); # optionally save it to commit changes.

returns 1 on success
returns nothing if entry did not exist	


=head2 get_user()

get userdirs line entry data by path, returns hash

	my $userx = $scanshare->get_user('/path/to/target_directory');
	print $userx->{label} . ' is set up to scan to directory: '. $userx->{path};

=head2 save()

save changes to userdirs file

	$scanshare->save();

=head2 count()

returns how many userdirs there are

	my $count = $scanshare->count();
















=head1 PRIVATE METHODS

=cut












=head1 NOTES

Example of a valid USERDIRS.TXT file:

	[PreferredServer]
	Server=192.168.0.130
	[RoutingID]
	NextID=4
	[Users]
	Great Place=relative\to\userdirs\location,Great Place,Host04,1,0
	Also a Great Place=relative\also,Also a Great Place,Host04,2,0
	Documents=misc\documents,Documents,Host04,3,0

Note the increment 1, 2, 3..

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=cut
