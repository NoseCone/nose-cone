#!/bin/sh

#set +v

cabal install shake-nose-cone
shake-nose-cone $@
