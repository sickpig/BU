How to run your BU node with TOR on Ubuntu/Debian
#################################################

0) Install Bitcoin Unlimited
----------------------------

Go to:

   https://www.bitcoinunlimited.info/download

Chose the binaries that correspond to your operative system
and architecture. Suppose we want install the BU on a 64bit
Linux machine:

	https://www.bitcoinunlimited.info/downloads/bitcoinUnlimited-1.0.1-linux64.tar.gz

Now you should have the tar.gz in your Download directory, untar it
and place the files you'll into the bitcoinUnlimited-1.0.1/bin directory
in a directory included in your system path. These are the commands
that you should execute from a console:

	cd ~/Downloads
	tar xf bitcoinUnlimited-1.0.1-linux64.tar.gz
	sudo cp bitcoinUnlimited-1.0.1/bin/* /usr/local/bin

1) Install Tor
--------------

If you're using Ubuntu >= 16.04 just do `sudo apt install tor`.

If you are using Debian stable (Jessie) or Ubuntu < 16.04
please follow the instructions below.

Create a new file /etc/apt/source.list.d/tor.list which
should have to contain these two lines (you need to do it
via sudo):

	deb http://deb.torproject.org/torproject.org xenial main
	deb-src http://deb.torproject.org/torproject.org xenial main

(if your are using Debian Jessie just substitute xenial with jessie)

Then add the gpg key used to sign the packages by running
the following commands at your command prompt:

	gpg --keyserver keys.gnupg.net --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
	gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | sudo apt-key add -

You can install it with the following commands:

	sudo apt-get update
	sudo apt-get install tor

2) Make bitcoind work with Tor
------------------------------

Execute this command

	sudo adduser $USER debian-tor
	exec su -l $USER

Then add these lines to /etc/tor/torrc (e.g. sudo nano /etc/tor/torrc)

	ControlPort 9051
	CookieAuthentication 1
	HashedControlPassword <TheHashOfYourTorPassword>

to get the hash of you pwd just use this command

	tor --hash-password <YourTorPassword>

now add these lines to your bitcoin.conf file

	proxy=127.0.0.1:9050
	listen=1
	onlynet=onion
	listenonion=1
	discover=0
	torcontrol=127.0.0.1:9051
	torpassword=<TheHashOfYourTorPassword>

issue this command to get the url of your onion hidden service

	bitcoin-cli getnetworkinfo | grep -w addr

you should get an output like this one

	"address": "k3a23xgpg2jugxjr.onion"

Pick the onion domain and verify on bitnodes.21.co if you it is
reachable.

3) What to do in case of a DDoS against your node
-------------------------------------------------

Stop your node:

	bitcoin-cli stop

Remove your peer file and tor private key from bitcoin data dir

	cd ~/.bitcoin
	rm onion_private_key
	rm peers.dat

Removing the onion_private_key serve the aim to get a new onion URL for
your bitcoin node, in such a way your attacker won't be able to harm you
again in the near term cause the prev URL is not valid any more.

Removing peer.dat will let you fetch a bunch of new peers from the seeder
this somewhat reduce the risk of peering again with your attacker.

If you want to maintain the same onion URL across reboot avoid to delete
the onion private key file.

Restart your node:

	bitcoind -daemon
