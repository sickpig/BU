NOL network HowTo
=================

This guide contains instructions on how to connect to the NOL ("no limit") network
(nolnet from now on).

The roles one could play on the nolnet are: Miner, Validator, Transactions Generator.
In the following 3 paragraphs we are going to explain how to setup and configure the
software needed to play each role.

Validator (full node)
---------------------

First thing to remember even if the nol blockchain is in ~/.bitcoin/nol the conf file
where to store your custom configuration is ~/.bitcoin/bitcoin.conf

Execute the bitcoind with the `-chain_nol` flag or set `chain_nol=1` in bitcoin.conf

Increase the length of unconfirmed transaction chains to more that 25
in both directions (asc and desc). With this settings we could have
chain of 200 txns with a max size of 1002KB.

	limitdescendantcount=100
	limitdescendantsize=501
	limitancestorcount=100
	limitancestorsize=501

Set you rpc credential

	rpcuser=set-your-user-here
	rpcpassword=iset-your-password-here

Activate log debug for xthin

	debug=thin

It will be useful to evaluate the performance xthin when propagating big blocks

Miner
-----

Get the binaries from the Ubuntu PPA repo, bitcoinunlimted.info or compile from
source using the `release` branch

Use the same configuration describe in the previous paragraph.

If you are using a pool software to mine make sure it is not enforcing
consensus in its code code like:

- max block size
- max number of SigOps per block

For example eloipool hard coded 20K - 512 = 19488 as the maximum number of
sigops per block. To change it you need to modify this line

https://github.com/luke-jr/eloipool/blob/d488480c263c57a1e5151a6db3090d1413d3a054/merklemaker.py#L330

and set `sigoplimit` to something a lot higher, take into account that BU enforce a 20K SigOps count per MB.

Transactions Generator
----------------------

Being able to produce enough transactions to so that to feel bigger blocks you need to use a modified
version of BU that enhance the coin selection performances. With a normal BU version or even Core you
will be constrained to 1/2 txns per second.

	git clone -b coinselection --single-branch --depth 1 https://github.com/gandrewstone/BitcoinUnlimited coinselect
	cd coinselect
	./autogen.sh
	./configure --without-gui
	make -j4

Then you need to use `txnTest.py` to actually generate transactions. Clone the repo where it is stored:

	git clone -b master --single-branch --depth 1 https://github.com/gandrewstone/BUtools butools

Since it depends on python bitcoin lib you need to install it before proceeding. To do it you have to
ways, the first one is via python pip:

	sudo apt-get install pip-python
	sudo pip install git+https://github.com/petertodd/python-bitcoinlib/

The second one is via git submodule

	cd butools
	git submodule init
	git submodule update
	export PYTHONPATH=.  # NB you need this if you're not installing python bitcoin lib in path were python could find it.
	                     # you could add it to your .bashrc to make it permanent

And now you can start generating transactions (this assumes you have nol token in your wallet in one address, or better UTXO)

	./txnTest.py nol split  #repeat this 3 times
	# this will start generating transaction
	./txnTest.py nol spam

