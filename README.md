# 🐲 Surdus Successore
Audio Based Side Channel Communication



## Project Overview

In this project, we implemented a method of communcation using audio signals that is not sensible to most adults. By integrating the frequency domain modulation and the phase domain modulation, we achieved a transmit rate up to 1000 bps.



## Products

This repository provides 2 relative products: a decoder and an encoder which are implemented in language ``Swift`` and tested on a MacBook Pro (Retina, 15-inch, Mid 2014). They are supposed to work well with all machines running macOS with version higher than 10.15. 

We only provide the source codes and XCode projects of the products. You may build them on your own machine.



### Encoder

The project of the encoder is located in [SurdusEncoder](https://github.com/WunschUnreif/Surdus-Successore/tree/master/Products/SurdusEncoder). It provides a user interface to choose the transmit rate and whether to use phase domain modulation or not. When using phase modulation, the transmit rate can be set up to 1000 bps, but no more than 800 bps is recommended. When using frequency modulation only, the transmit rate is limitted to 400 bps, but no more than 320 bps is recommended. The encoded audio signals can be played immediately or stored to your file system as a ``wav`` file.



### Decoder

The project of the decoder is located in [SurdusDncoder](https://github.com/WunschUnreif/Surdus-Successore/tree/master/Products/SurdusDecoder). It is auto-adaptive to the encoding method and the transmit rate. User does not need any extra configuration. There is just a "Run" button to start the decoding.



### Known Issue

- Due to the high error rate and the malfunctioning byte order, we do not recommend you to transmit non-ascii data using the products.



## Report

We will provide our project report and the presentation slides in the futrue.

