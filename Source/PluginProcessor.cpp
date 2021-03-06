#include "PluginProcessor.h"
#include "PluginEditor.h"

#include <math.h>

//==============================================================================
DafxAudioProcessor::DafxAudioProcessor()
{
    
    // Simplified Moog Defaults
    resonance = 0.10f;
    cutoff = 1000; 
    
    filterType = 0; 
    
    MoogLadder.add(new SimplifiedMoog()); 
    MoogLadder.add(new SimplifiedMoog()); 
    
}

DafxAudioProcessor::~DafxAudioProcessor()
{
}

//==============================================================================
const String DafxAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

int DafxAudioProcessor::getNumParameters()
{
    return totalNumParams;
}

float DafxAudioProcessor::getParameter (int index)
{
    switch (index)
    {
        case resParam: return resonance;
        case cutoffParam: return cutoff;
        default: return 0.0f;
    }
    
}

void DafxAudioProcessor::setParameter (int index, float newValue)
{
    
    switch (index)
    {
        case resParam: resonance = newValue; changeFilterResonance(newValue); break;
        case cutoffParam: cutoff = newValue; changeFilterCutoff(newValue); break;
            
        case setSimplified: changeFilterType(0); break; 
        case setStilson: changeFilterType(1); break;
        case setHuovilainen: changeFilterType(2); break;
            
        default: break;
    }

}

const String DafxAudioProcessor::getParameterName (int index)
{
    switch (index)
    {
        case resParam: return "Resonance";
        case cutoffParam: return "Cutoff";
        default: break;
    }
    
    return String::empty;
}

const String DafxAudioProcessor::getParameterText (int index)
{
    return String (getParameter (index), 2);
}

const String DafxAudioProcessor::getInputChannelName (int channelIndex) const
{
    return String (channelIndex + 1);
}

const String DafxAudioProcessor::getOutputChannelName (int channelIndex) const
{
    return String (channelIndex + 1);
}

bool DafxAudioProcessor::isInputChannelStereoPair (int index) const
{
    return true;
}

bool DafxAudioProcessor::isOutputChannelStereoPair (int index) const
{
    return true;
}

bool DafxAudioProcessor::acceptsMidi() const
{
#if JucePlugin_WantsMidiInput
    return true;
#else
    return false;
#endif
}

bool DafxAudioProcessor::producesMidi() const
{
#if JucePlugin_ProducesMidiOutput
    return true;
#else
    return false;
#endif
}

int DafxAudioProcessor::getNumPrograms()
{
    return 0;
}

int DafxAudioProcessor::getCurrentProgram()
{
    return 0;
}

void DafxAudioProcessor::setCurrentProgram (int index)
{
}

const String DafxAudioProcessor::getProgramName (int index)
{
    return String::empty;
}

void DafxAudioProcessor::changeProgramName (int index, const String& newName)
{
}

//==============================================================================
void DafxAudioProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    // Use this method as the place to do any pre-playback
    // initialisation that you need..
}

//=============================================================================
void DafxAudioProcessor::releaseResources()
{
    // When playback stops, you can use this as an opportunity to free up any
    // spare memory, etc.
}

//=============================================================================
void DafxAudioProcessor::processBlock (AudioSampleBuffer& buffer, MidiBuffer& midiMessages)
{
    int numSamples = buffer.getNumSamples();
    int channel; 
    
    for (channel = 0; channel < getNumInputChannels(); ++channel) 
    {
        
        float* channelData = buffer.getSampleData (channel);
        MoogLadder[channel]->processSamples(channelData, numSamples);  

    }

    for (int i = getNumInputChannels(); i < getNumOutputChannels(); ++i) 
    {
        buffer.clear (i, 0, buffer.getNumSamples());
    }
    
}


//==============================================================================

void DafxAudioProcessor::changeFilterType(int newType)
{
 
    if (newType == filterType) return; 
        
    MoogLadder.clear();
    
    switch (newType)
    {
        case 0: 
            filterType = 0; 
            MoogLadder.add(new SimplifiedMoog()); 
            MoogLadder.add(new SimplifiedMoog());
            break; 
        case 1: 
            filterType = 1; 
            MoogLadder.add(new StilsonMoog()); 
            MoogLadder.add(new StilsonMoog());
            break;
        case 2:
            filterType = 2; 
            MoogLadder.add(new HuovilainenMoog()); 
            MoogLadder.add(new HuovilainenMoog());
            break;
    }
    
    changeFilterType(resonance);
    changeFilterCutoff(cutoff); 
        
}


void DafxAudioProcessor::changeFilterResonance(float newR)
{
    
    MoogLadder[0]->computeResonance(newR); 
    MoogLadder[1]->computeResonance(newR); 

}

void DafxAudioProcessor::changeFilterCutoff(float newC)
{
    
    MoogLadder[0]->computeCutoff(newC); 
    MoogLadder[1]->computeCutoff(newC); 
    
}

//==============================================================================
bool DafxAudioProcessor::hasEditor() const
{
    return true; // (change this to false if you choose to not supply an editor)
}

AudioProcessorEditor* DafxAudioProcessor::createEditor()
{
    return new DafxAudioProcessorEditor (this);
}

//==============================================================================
void DafxAudioProcessor::getStateInformation (MemoryBlock& destData)
{
    // You should use this method to store your parameters in the memory block.
    // You could do that either as raw data, or use the XML or ValueTree classes
    // as intermediaries to make it easy to save and load complex data.
}

void DafxAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    // You should use this method to restore your parameters from this memory block,
    // whose contents will have been created by the getStateInformation() call.
}

//==============================================================================
// This creates new instances of the plugin..
AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new DafxAudioProcessor();
}
