/*
  ==============================================================================

   This file is part of the JUCE library - "Jules' Utility Class Extensions"
   Copyright 2004-11 by Raw Material Software Ltd.

  ------------------------------------------------------------------------------

   JUCE can be redistributed and/or modified under the terms of the GNU General
   Public License (Version 2), as published by the Free Software Foundation.
   A copy of the license is included in the JUCE distribution, or can be found
   online at www.gnu.org/licenses.

   JUCE is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
   A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  ------------------------------------------------------------------------------

   To release a closed-source product which uses JUCE, commercial licenses are
   available: visit www.rawmaterialsoftware.com/juce for more information.

  ==============================================================================
*/

namespace CDReaderHelpers
{
    inline const XmlElement* getElementForKey (const XmlElement& xml, const String& key)
    {
        forEachXmlChildElementWithTagName (xml, child, "key")
            if (child->getAllSubText().trim() == key)
                return child->getNextElement();

        return nullptr;
    }

    static int getIntValueForKey (const XmlElement& xml, const String& key, int defaultValue = -1)
    {
        const XmlElement* const block = getElementForKey (xml, key);
        return block != nullptr ? block->getAllSubText().trim().getIntValue() : defaultValue;
    }

    // Get the track offsets for a CD given an XmlElement representing its TOC.Plist.
    // Returns NULL on success, otherwise a const char* representing an error.
    static const char* getTrackOffsets (XmlDocument& xmlDocument, Array<int>& offsets)
    {
        const ScopedPointer<XmlElement> xml (xmlDocument.getDocumentElement());
        if (xml == nullptr)
            return "Couldn't parse XML in file";

        const XmlElement* const dict = xml->getChildByName ("dict");
        if (dict == nullptr)
            return "Couldn't get top level dictionary";

        const XmlElement* const sessions = getElementForKey (*dict, "Sessions");
        if (sessions == nullptr)
            return "Couldn't find sessions key";

        const XmlElement* const session = sessions->getFirstChildElement();
        if (session == nullptr)
            return "Couldn't find first session";

        const int leadOut = getIntValueForKey (*session, "Leadout Block");
        if (leadOut < 0)
            return "Couldn't find Leadout Block";

        const XmlElement* const trackArray = getElementForKey (*session, "Track Array");
        if (trackArray == nullptr)
            return "Couldn't find Track Array";

        forEachXmlChildElement (*trackArray, track)
        {
            const int trackValue = getIntValueForKey (*track, "Start Block");
            if (trackValue < 0)
                return "Couldn't find Start Block in the track";

            offsets.add (trackValue * AudioCDReader::samplesPerFrame - 88200);
        }

        offsets.add (leadOut * AudioCDReader::samplesPerFrame - 88200);
        return nullptr;
    }

    static void findDevices (Array<File>& cds)
    {
        File volumes ("/Volumes");
        volumes.findChildFiles (cds, File::findDirectories, false);

        for (int i = cds.size(); --i >= 0;)
            if (! cds.getReference(i).getChildFile (".TOC.plist").exists())
                cds.remove (i);
    }

    struct TrackSorter
    {
        static int getCDTrackNumber (const File& file)
        {
            return file.getFileName().initialSectionContainingOnly ("0123456789").getIntValue();
        }

        static int compareElements (const File& first, const File& second)
        {
            const int firstTrack  = getCDTrackNumber (first);
            const int secondTrack = getCDTrackNumber (second);

            jassert (firstTrack > 0 && secondTrack > 0);

            return firstTrack - secondTrack;
        }
    };
}

//==============================================================================
StringArray AudioCDReader::getAvailableCDNames()
{
    Array<File> cds;
    CDReaderHelpers::findDevices (cds);

    StringArray names;

    for (int i = 0; i < cds.size(); ++i)
        names.add (cds.getReference(i).getFileName());

    return names;
}

AudioCDReader* AudioCDReader::createReaderForCD (const int index)
{
    Array<File> cds;
    CDReaderHelpers::findDevices (cds);

    if (cds[index].exists())
        return new AudioCDReader (cds[index]);

    return nullptr;
}

AudioCDReader::AudioCDReader (const File& volume)
   : AudioFormatReader (0, "CD Audio"),
     volumeDir (volume),
     currentReaderTrack (-1),
     reader (0)
{
     sampleRate = 44100.0;
     bitsPerSample = 16;
     numChannels = 2;
     usesFloatingPointData = false;

     refreshTrackLengths();
}

AudioCDReader::~AudioCDReader()
{
}

void AudioCDReader::refreshTrackLengths()
{
    tracks.clear();
    trackStartSamples.clear();
    lengthInSamples = 0;

    volumeDir.findChildFiles (tracks, File::findFiles | File::ignoreHiddenFiles, false, "*.aiff");

    CDReaderHelpers::TrackSorter sorter;
    tracks.sort (sorter);

    const File toc (volumeDir.getChildFile (".TOC.plist"));

    if (toc.exists())
    {
        XmlDocument doc (toc);
        const char* error = CDReaderHelpers::getTrackOffsets (doc, trackStartSamples);
        (void) error; // could be logged..

        lengthInSamples = trackStartSamples.getLast() - trackStartSamples.getFirst();
    }
}

bool AudioCDReader::readSamples (int** destSamples, int numDestChannels, int startOffsetInDestBuffer,
                                 int64 startSampleInFile, int numSamples)
{
    while (numSamples > 0)
    {
        int track = -1;

        for (int i = 0; i < trackStartSamples.size() - 1; ++i)
        {
            if (startSampleInFile < trackStartSamples.getUnchecked (i + 1))
            {
                track = i;
                break;
            }
        }

        if (track < 0)
            return false;

        if (track != currentReaderTrack)
        {
            reader = nullptr;

            FileInputStream* const in = tracks [track].createInputStream();

            if (in != nullptr)
            {
                BufferedInputStream* const bin = new BufferedInputStream (in, 65536, true);

                AiffAudioFormat format;
                reader = format.createReaderFor (bin, true);

                if (reader == nullptr)
                    currentReaderTrack = -1;
                else
                    currentReaderTrack = track;
            }
        }

        if (reader == nullptr)
            return false;

        const int startPos = (int) (startSampleInFile - trackStartSamples.getUnchecked (track));
        const int numAvailable = (int) jmin ((int64) numSamples, reader->lengthInSamples - startPos);

        reader->readSamples (destSamples, numDestChannels, startOffsetInDestBuffer, startPos, numAvailable);

        numSamples -= numAvailable;
        startSampleInFile += numAvailable;
    }

    return true;
}

bool AudioCDReader::isCDStillPresent() const
{
    return volumeDir.exists();
}

void AudioCDReader::ejectDisk()
{
    JUCE_AUTORELEASEPOOL
    [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath: juceStringToNS (volumeDir.getFullPathName())];
}

bool AudioCDReader::isTrackAudio (int trackNum) const
{
    return tracks [trackNum].hasFileExtension (".aiff");
}

void AudioCDReader::enableIndexScanning (bool)
{
    // any way to do this on a Mac??
}

int AudioCDReader::getLastIndex() const
{
    return 0;
}

Array<int> AudioCDReader::findIndexesInTrack (const int /*trackNumber*/)
{
    return Array<int>();
}
