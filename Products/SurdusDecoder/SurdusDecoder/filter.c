//
//  filter.c
//  SurdusDecoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 SJTU. All rights reserved.
//

#include "filter.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <memory.h>

void MovingAverageWindowInit(MovingAverageWindow * window, float fs, float firstzero) {
    window->windowLength = (int)(fs / firstzero);
    window->currSum = 0;
    window->numSum = 0;
    window->head = window->tail = 0;
}

void MovingAverageWindowPush(MovingAverageWindow * window, float data) {
    window->tail = window->tail + 1 >= window->windowLength ?
                    window->tail + 1 - window->windowLength :
                    window->tail + 1;
    
    window->dataWindow[window->tail] = data;
    window->currSum += data;
    
    if(window->tail != window->head) {
        window->numSum += 1;
    } else {
        window->head = window->head + 1 >= window->windowLength ?
                        window->head + 1 - window->windowLength :
                        window->head + 1;
        window->currSum -= window->dataWindow[window->head];
    }
}

float MovingAverageWindowGet(MovingAverageWindow * window) {
    return window->currSum / window->numSum;
}


void SingleFreqFilterInit(SingleFreqFilter * filter, float sampleRate, float targetFreq) {
    filter->sampleRate = sampleRate;
    filter->targetFreq = targetFreq;
    
    MovingAverageWindowInit(&filter->windowI, sampleRate, 100);
    MovingAverageWindowInit(&filter->windowQ, sampleRate, 100);
    
    filter->currStep = 0;
    filter->bufferI = 0;
    filter->bufferQ = 0;
    filter->bufferCount = 0;
    
    filter->cosTable = malloc(sizeof(float) * 192000);
    filter->sinTable = malloc(sizeof(float) * 192000);
    
    for(int step = 0; step < sampleRate; ++step) {
        float time = step / sampleRate;
        filter->cosTable[step] =  cos(2 * M_PI * targetFreq * time);
        filter->sinTable[step] = -sin(2 * M_PI * targetFreq * time);
    }
}

int SinglaFreqFilterPush(SingleFreqFilter * filter, float data, float * power, float * phase) {
    float cosSample = data * filter->cosTable[filter->currStep];
    float sinSample = data * filter->sinTable[filter->currStep];
    
    filter->currStep += 1;
    if(filter->currStep >= filter->sampleRate) {
        filter->currStep -= filter->sampleRate;
    }
    
    MovingAverageWindowPush(&filter->windowI, cosSample);
    MovingAverageWindowPush(&filter->windowQ, sinSample);
    
    filter->bufferI += MovingAverageWindowGet(&filter->windowI);
    filter->bufferQ += MovingAverageWindowGet(&filter->windowQ);
    filter->bufferCount += 1;
    
    if(filter->bufferCount >= filter->sampleRate / 1000) {
        float avgI = filter->bufferI / filter->bufferCount;
        float avgQ = filter->bufferQ / filter->bufferCount;
        
        *power = 20 * log10f(avgI * avgI + avgQ * avgQ);
        *phase = atan2f(avgI, avgQ);
        
        filter->bufferI = 0;
        filter->bufferQ = 0;
        filter->bufferCount = 0;
        return 1;
    } else {
        return 0;
    }
}

const float keyFreqs[] = {
    16000, 17400, 17500, 17600, 17700, 17800, 17900,
    18000, 18100, 18200, 18300,
    18400, 18500, 18600, 18700,
    18800, 18900, 19000, 19100,
    19200, 19300, 19400, 19500
};

void AnalticsInit(Analytics * anal, float sampleRate) {
    anal->filters = malloc(sizeof(SingleFreqFilter) * 23);
    anal->phases = malloc(sizeof(float) * 23);
    anal->powers = malloc(sizeof(float) * 23);
    for(int i = 0; i < 23; ++i) {
        SingleFreqFilterInit(&anal->filters[i], sampleRate, keyFreqs[i]);
    }
}

void AnalticsPush(Analytics * anal, float data) {
    float phase, power;
    int update = 0;
    for (int i = 0; i < 23; ++i) {
        update = SinglaFreqFilterPush(&anal->filters[i], data, &power, &phase);
        if(update) {
            anal->powers[i] = power;
            anal->phases[i] = phase;
        }
    }
    if(update) {
        anal->updated = 1;
    }
}

