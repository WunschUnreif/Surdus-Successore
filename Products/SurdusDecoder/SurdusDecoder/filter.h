//
//  filter.h
//  SurdusDecoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 @WunschUnreif. All rights reserved.
//

#ifndef filter_h
#define filter_h

#include <stdio.h>

typedef struct _MovingAverageWindow {
    float dataWindow[2048];
    int head, tail;
    int windowLength;
    
    float currSum;
    int numSum;
} MovingAverageWindow;

void MovingAverageWindowInit(MovingAverageWindow * window, float fs, float firstzero);
void MovingAverageWindowPush(MovingAverageWindow * window, float data);
float MovingAverageWindowGet(MovingAverageWindow * window);

typedef struct _SingleFreqFilter {
    MovingAverageWindow windowI;
    MovingAverageWindow windowQ;
    
    int sampleRate;
    float targetFreq;
    
    int currStep;
    
    float * cosTable;
    float * sinTable;
    
    float bufferI;
    float bufferQ;
    int bufferCount;
} SingleFreqFilter;
void SingleFreqFilterInit(SingleFreqFilter * filter, float sampleRate, float targetFreq);
int SinglaFreqFilterPush(SingleFreqFilter * filter, float data, float * power, float * phase);


typedef struct _Analytics {
    SingleFreqFilter * filters;
    
    float * powers;
    float * phases;
    int updated;
} Analytics;
void AnalticsInit(Analytics * anal, float sampleRate);
void AnalticsPush(Analytics * anal, float data);


#endif /* filter_h */
