//
//  OngoingTalk.m
//  Quantle
//
//  Created by Olga Saukh on 5/05/17.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2017 Olga Saukh
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "OngoingTalk.h"

@implementation OngoingTalk

static TalkData *td;

+ (TalkData*)getInstance {
    if (td == nil) {
        td = [[TalkData alloc] init];
        
        td.speakerName = @"Alice Armstrong";
        td.speakerPicture = UIImagePNGRepresentation([UIImage imageNamed:@"face32x32.png"]);
        td.eventName = @"Sample Talk";
        td.date = [NSDate date];
        
        zeroFields();
    }
    return td;
}

void zeroFields () {
    td.talkLength = 0;
    
    td.meanRateAsSyllablesPerMinute = 0;
    td.meanRateAsWordsPerMinute = 0;
    td.meanPitch = 0;
    td.meanVolume = 0;
    td.meanPausesPerMinute = 0;
    td.meanPauseDuration = 0;
    
    td.totalSyllables = 0;
    td.totalWords = 0;
    td.totalSentences = 0;
    
    td.varRateAsSyllablesPerMinute = 0;
    td.varPitch = 0;
    td.varVolume = 0;
    
    td.histRateAsSyllablesPerMinute = [[NSMutableArray alloc] init];
    td.classWordsBySyllables = [[NSMutableArray alloc] init];
    td.classPausesByLength = [[NSMutableArray alloc] init];
    td.histPitch = [[NSMutableArray alloc] init];
    td.histVolume = [[NSMutableArray alloc] init];
    
    td.fleschReadingEase = 0;
    td.fleschKincaidGradeEase = 0;
    td.gunningFogIndex = 0;
    td.forecastGradeLevel = 0;
    
    td.isShared = 0;
}

+ (TalkData*)resetInstance {
    if (td == nil)
        td = [[TalkData alloc] init];
    
    td.speakerPicture = UIImagePNGRepresentation([UIImage imageNamed:@"face32x32.png"]);
    td.date = [NSDate date];
    
    zeroFields();
    return td;
}

+(TalkData*) resetTime {
    td.date = [NSDate date];
    
    return td;
}

+(TalkData*) setInstance {
    // Update all counters
    
    // counters
    td.talkLength = @( counters.talk_duration );
    td.totalSyllables = @( counters.num_syllables );
    td.totalWords = @( counters.num_words );
    td.totalSentences = @( counters.num_clauses );
    
    // rate
    if (counters.talk_duration)
        td.meanRateAsSyllablesPerMinute = @( counters.num_syllables / counters.talk_duration );
    if (counters.talk_duration)
        td.meanRateAsWordsPerMinute = @( counters.num_words / counters.talk_duration );
    [OngoingTalk setRateData];
    
    // pauses
    if (counters.talk_duration)
        td.meanPauseDuration = @( counters.sum_pause_duration / counters.talk_duration / 60);
    
    // pitch
    [OngoingTalk setPitchData];
    
    // volume
    [OngoingTalk setVolumeData];
    
    // histograms and classifications
    for (int i=0; i<HIST_MAX_VALUES; i++)
        [td.histRateAsSyllablesPerMinute addObject:@(counters.pace_histogram[i])];
    for (int i=0; i<4; i++)
        [td.classWordsBySyllables addObject:@(counters.words_by_syllables[i])];
    for (int i=0; i<6; i++)
        [td.classPausesByLength addObject:@(counters.pauses_by_length[i])];
    for (int i=0; i<HIST_MAX_VALUES; i++)
        [td.histPitch addObject:@(counters.pitch_histogram[i])];
    for (int i=0; i<HIST_MAX_VALUES; i++)
        [td.histVolume addObject:@(counters.power_histogram[i])];
    
    // comprehension scores
    ASP_compute_comprehension_scores();
    td.fleschReadingEase = @( counters.flesch_reading_ease );
    td.fleschKincaidGradeEase = @( counters.flesch_kincaid_grade_ease );
    td.gunningFogIndex = @( counters.gunning_fog_index );
    td.forecastGradeLevel = @( counters.forecast_grade_level );
    
    return td;
}

+(void) setPitchData {
    int num_pitch = 0, sum_pitch = 0;
    for (int i=0; i<HIST_MAX_VALUES; i++) {
        sum_pitch += (counters.pitch_histogram[i] * (i * 15 + 60));
        num_pitch += counters.pitch_histogram[i];
    }
    td.meanPitch = (num_pitch > 0) ? @( ((float) sum_pitch) / num_pitch ) : @(0);
    
    // find var
    float rmse = 0;
    for (int i=0; i<HIST_MAX_VALUES; i++)
        rmse += ( powf(i-(td.meanPitch.floatValue-60)/15,2) * 144 ) * counters.pitch_histogram[i];
//    td.varPitch = (num_pitch > 0) ? @( sqrtf(rmse / num_pitch) / [td.meanPitch floatValue] * 100 ) : @(0);
    td.varPitch = (num_pitch > 0) ? @( sqrtf(rmse / num_pitch) / 150.0 * 100 ) : @(0);
}

+(void) setRateData {
    int num_rate = 0, sum_rate = 0;
    for (int i=0; i<HIST_MAX_VALUES; i++) {
        sum_rate += (counters.pace_histogram[i] * (i * 30));
        num_rate += counters.pace_histogram [i];
    }
    
    // find var
    float rmse = 0;
    for (int i=0; i<HIST_MAX_VALUES; i++)
        rmse += ( powf(i-td.meanRateAsSyllablesPerMinute.floatValue/30,2) * 900 ) * counters.pace_histogram[i];
    td.varRateAsSyllablesPerMinute = (num_rate > 0 && td.meanRateAsSyllablesPerMinute > 0) ? @( sqrtf(rmse / num_rate) / [td.meanRateAsSyllablesPerMinute floatValue] * 100) : @(0);
}

+(void) setVolumeData {
    int num_volume = 0, sum_volume = 0;
    for (int i=0; i<HIST_MAX_VALUES; i++) {
        sum_volume += counters.power_histogram[i] * i;
        num_volume += counters.power_histogram[i];
    }
    td.meanVolume = (num_volume > 0) ? @( ((float) sum_volume) / num_volume ) : @(0);
    
    // find var
    float rmse = 0;
    for (int i=0; i<HIST_MAX_VALUES; i++)
        rmse += ( powf(i-td.meanVolume.floatValue,2) ) * counters.power_histogram[i];
    td.varVolume = (num_volume > 0) ? @( sqrtf(rmse / num_volume) / [td.meanVolume floatValue] * 100 ) : @(0);
}

@end
