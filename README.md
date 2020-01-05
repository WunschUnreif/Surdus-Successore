# 🐲 Surdus Successore
Audio Based Side Channel Communication  [SJTU CS339 Fall 2019 Final Project]



## Project Overview

In this project, we implemented a method of communcation using audio signals that is not sensible to most adults. By integrating the frequency domain modulation and the phase domain modulation, we achieved a transmit rate up to 1200 bps.



## Products

This repository provides 2 relative products: a decoder and an encoder which are implemented in language ``Swift`` and tested on a MacBook Pro (Retina, 15-inch, Mid 2014). They are supposed to work well with all machines running macOS with version higher than 10.15. 

We only provide the source codes and XCode projects of the products. You may build them on your own machine.



### Encoder

The project of the encoder is located in [SurdusEncoder](https://github.com/WunschUnreif/Surdus-Successore/tree/master/Products/SurdusEncoder). It provides a user interface to choose the transmit rate and whether to use phase domain modulation or not. When using phase modulation, the transmit rate can be set up to 1200 bps, but no more than 800 bps is recommended. When using frequency modulation only, the transmit rate is limitted to 600 bps, but no more than 400 bps is recommended. The encoded audio signals can be played immediately or stored to your file system as a ``wav`` file.



### Decoder

The project of the decoder is located in [SurdusDecoder](https://github.com/WunschUnreif/Surdus-Successore/tree/master/Products/SurdusDecoder). It is auto-adaptive to the encoding method and the transmit rate. User does not need any extra configuration. There is just a "Run" button to start the decoding.



### Known Issue

- Sometimes the decoder recognizes extra data after the sound is finished since there may be echo waves. This can be fixed by adding frame head and tails. But since we focus on the physical layer only, this problem is not very severe to us.



## Report

We provided our presentation slides in the `Report/` folder.

