use Test::Simple 'no_plan';
use lib './lib';
use Device::ScanShare;
use Cwd;
use Smart::Comments '###';

unlink cwd().'/t/USERDIRS.txt';


my $s = new Device::ScanShare({
	userdirs_abs_path => cwd().'/t/USERDIRS.txt',
	server => '192.168.0.150',
	default_host => 'Dyer05',
});

ok(!$s->exists,'userdirs does not exist');

ok($s->create,'userdirs created');





ok( !(scalar @{$s->get_users}), 'get_users returns 0');

mkdir cwd().'/t/userx';
mkdir cwd().'/t/usery';
mkdir cwd().'/t/userz';


ok($s->user_add({ label => 'User X', path => cwd().'/t/userx/' }), 'added userx');
ok($s->user_add({ label => 'User Y', path => cwd().'/t/usery/' }), 'added usery');
ok($s->user_add({ label => 'User Z', path => cwd().'/t/userz/' }), 'added userz');

ok( (scalar @{$s->get_users}) ==3, 'get_users now returns 3');


ok($s->user_delete(cwd().'/t/userx/'),'remove user X');

ok( (scalar @{$s->get_users}) ==2, 'get_users now returns 2');



my $userz = $s->get_user(cwd().'/t/userz/');

### $userz






ok( $s->save,'userdirs saved');


my $u = $s->get_users;
### $u


#unlink cwd().'/t/USERDIRS.txt';


