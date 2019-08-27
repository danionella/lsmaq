classdef rigClass < dynamicprops
    %rigClass holds all the variables linked with the setup hardware (Analog I/O channels, triggers etc.)

    properties (SetAccess=private) %check these settings. If you are not sure about your device names, check NI MAX Automation explorer
        AIrate                            % analog input sample rate in Hz
        AOrate                             % analog output sample rate in Hz (has to be divisor of AIrate)
        AIrange                           % analog input voltage range (2-element vector)
        AIchans                   % path to AI channels (primary DAQ card)
        shutterline                 % path to shutter output line (primary DAQ card)
        AOchans                  % cell array of AO channel paths. For a single AO card, this would be a 1-element cell, e.g. {'Dev1/ao0:1'}, for two cards, this could be {'Dev1/ao0:1', 'Dev2/ao0:2'}
        channelOrder                     % cell array of signal to channel assignments. Assign [X,Y,Z,Blank,Phase] signals (in that order, 1-based indexing) to output channels. To assign X to the first output channel, Y to the second, blank to the first of the second card and Z to the second of the second card, use {[1 2], [4 3]}. For a single output card, this could be e.g. {[1 2]}
        pmtPolarity                           % invert PMT polarity, if needed (value: 1 or -1)
        gateline             % path to digital output of gating/blanking signal
        stageCreator                          % function that takes no arguments and returns a stage object (containing methods getPos and setPos, e.g. @() MP285('COM3', [10 10 25])) or empty
        powercontrolCreator                   % function that takes no arguments and returns a powercontrol object (containing methods getPos and setPos) or an empty scalar ('@() []')
    end

    properties
        laserSyncPort                               % leave empty if not syncing, sets SampleClock source of AI and TimeBaseSource of AO object, pulse rate is assumed to be AIRate
        stage
        powercontrol
        isScanning = false;
    end

    properties (SetAccess=private)
        AItask
        AIreader
        AIlistener
        AOtask
        AOwriter
        TriggerTask
        ShutterTask
        GateTask
        GateTaskWriter
        GateCloseTask
        GateCloseWriter
        ShutterWriter
    end

    methods

        %rigClass constructor
        function obj = rigClass(rigcfg, fStatus)
            if nargin >=1
                for iFn = fieldnames(rigcfg)'
                    obj.(iFn{1}) = rigcfg.(iFn{1});
                end
            end
            if nargin < 2 || isempty(fStatus)
                fprintf(1, 'Starting up rig:    ');
                fStatus = @(fraction, text) fprintf(1, '\b\b\b%02.0f%%', fraction*100);
            end

            % load NIDAQmx .NET assembly
            fStatus(0/6, 'starting up: loading DAQmx...')
            try
                NET.addAssembly('NationalInstruments.DAQmx');
                import NationalInstruments.DAQmx.*
            catch
                error('Error loading .NET assembly! Check NIDAQmx .NET installation.')
            end

            % Reset DAQ boards
            fStatus(1/6, 'starting up: resetting DAQ...')
            for iDev = unique(strtok([{obj.AIchans} obj.AOchans], '/'))
                DaqSystem.Local.LoadDevice(iDev{1}).Reset
            end

            % Setting up device objects
            fStatus(2/6, 'starting up: setting up DAQ...')
            obj.AItask = NationalInstruments.DAQmx.Task;
            obj.AItask.AIChannels.CreateVoltageChannel(obj.AIchans, '', AITerminalConfiguration.Differential,obj.AIrange(1),obj.AIrange(2), AIVoltageUnits.Volts);
            obj.AItask.Timing.ConfigureSampleClock(obj.laserSyncPort, obj.AIrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, 100)
            %obj.AItask.Timing.ConfigureSampleClock('', obj.AIrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, 100)
            %obj.AItask.Timing.SampleClockTimebaseSource = 'PFI5';
            %obj.AItask.Timing.SampleClockTimebaseRate = 4e6;
            obj.AItask.Triggers.StartTrigger.ConfigureDigitalEdgeTrigger('PFI0', DigitalEdgeStartTriggerEdge.Rising);  %obj.AItask.ExportSignals.ExportHardwareSignal(ExportSignal.StartTrigger, 'PFI0');
            obj.AItask.Control(TaskAction.Verify);
            obj.AIreader = AnalogUnscaledReader(obj.AItask.Stream);


            obj.AOtask{1} = NationalInstruments.DAQmx.Task;
            obj.AOtask{1}.AOChannels.CreateVoltageChannel(obj.AOchans{1}, '',-10, 10, AOVoltageUnits.Volts);
            obj.AOtask{1}.Stream.WriteRegenerationMode = WriteRegenerationMode.AllowRegeneration;
            obj.AOtask{1}.Timing.ConfigureSampleClock('', obj.AOrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, 100)
            if ~isempty(obj.laserSyncPort)
                obj.AOtask{1}.Timing.SampleClockTimebaseSource = obj.laserSyncPort;
                obj.AOtask{1}.Timing.SampleClockTimebaseRate = obj.AIrate;
            else
                obj.AOtask{1}.Timing.SampleClockTimebaseSource = '100MHzTimebase';
                obj.AOtask{1}.Timing.SampleClockTimebaseRate = 100e6;
            end
            obj.AOtask{1}.Triggers.StartTrigger.ConfigureDigitalEdgeTrigger('PFI0', DigitalEdgeStartTriggerEdge.Rising);
            obj.AOtask{1}.ExportSignals.ExportHardwareSignal(ExportSignal.SampleClock, 'PFI7');
            obj.AOtask{1}.Control(TaskAction.Verify);
            obj.AOwriter{1} = AnalogMultiChannelWriter(obj.AOtask{1}.Stream);

            for i = 2:numel(obj.AOchans)
                obj.AOtask{i} = NationalInstruments.DAQmx.Task;
                obj.AOtask{i}.AOChannels.CreateVoltageChannel(obj.AOchans{2}, '',-10, 10, AOVoltageUnits.Volts);
                obj.AOtask{i}.Stream.WriteRegenerationMode = WriteRegenerationMode.AllowRegeneration;
                obj.AOtask{i}.Timing.ConfigureSampleClock('PFI7', obj.AOrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, 100)
                obj.AOtask{i}.Triggers.StartTrigger.ConfigureDigitalEdgeTrigger('PFI0', DigitalEdgeStartTriggerEdge.Rising);
                obj.AOtask{i}.Control(TaskAction.Verify);
                obj.AOwriter{i} = AnalogMultiChannelWriter(obj.AOtask{i}.Stream);
            end

            obj.GateTask = NationalInstruments.DAQmx.Task;
            obj.GateTask.DOChannels.CreateChannel(obj.gateline,'',ChannelLineGrouping.OneChannelForEachLine);
            obj.GateTask.Stream.WriteRegenerationMode = WriteRegenerationMode.AllowRegeneration;
            obj.GateTask.Timing.ConfigureSampleClock('', obj.AOrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, 100)
            obj.GateTask.Timing.SampleClockTimebaseSource = obj.AOtask{1}.Timing.SampleClockTimebaseSource;
            obj.GateTask.Timing.SampleClockTimebaseRate = obj.AOtask{1}.Timing.SampleClockTimebaseRate;
            obj.GateTask.Triggers.StartTrigger.ConfigureDigitalEdgeTrigger('PFI0', DigitalEdgeStartTriggerEdge.Rising);
            obj.GateTask.Control(TaskAction.Verify);
            obj.GateTaskWriter = DigitalSingleChannelWriter(obj.GateTask.Stream);

            obj.GateCloseTask = NationalInstruments.DAQmx.Task;
            obj.GateCloseTask.DOChannels.CreateChannel(obj.gateline,'',ChannelLineGrouping.OneChannelForEachLine);
            obj.GateCloseTask.Control(TaskAction.Verify);
            obj.GateCloseWriter = DigitalSingleChannelWriter(obj.GateCloseTask.Stream);

            obj.ShutterTask = NationalInstruments.DAQmx.Task;
            obj.ShutterTask.DOChannels.CreateChannel(obj.shutterline,'',ChannelLineGrouping.OneChannelForEachLine);
            obj.ShutterTask.Control(TaskAction.Verify);
            obj.ShutterWriter = DigitalSingleChannelWriter(obj.ShutterTask.Stream);

            obj.TriggerTask = NationalInstruments.DAQmx.Task;
            primaryDev = strtok(obj.AIchans, '/');
            obj.TriggerTask.COChannels.CreatePulseChannelTime(['/' primaryDev '/Ctr0'], '', COPulseTimeUnits.Seconds, COPulseIdleState.Low, 0, 0.1, 0.1);
            obj.TriggerTask.Control(TaskAction.Verify);

            fStatus(4/6, 'starting up: adding stage...');
            if ~isempty(obj.stageCreator)
                obj.stage = obj.stageCreator();
            end

            fStatus(5/6, 'starting up: adding power control...');
            if ~isempty(obj.powercontrolCreator)
                obj.powercontrol = obj.powercontrolCreator();
            end

            fStatus(1); fprintf(1, '\n');
        end

        function shutterClose(obj)
            % Closes shutter
            obj.ShutterWriter.WriteSingleSampleSingleLine(true, false);
        end

        function shutterOpen(obj)
            % Opens shutter
            obj.ShutterWriter.WriteSingleSampleSingleLine(true, true);
        end

        function hwTrigger(obj)
            % Launch hardware trigger
            obj.TriggerTask.Start
            obj.TriggerTask.WaitUntilDone(-1)
            obj.TriggerTask.Stop
        end

        function queueOutputData(obj, scannerOut)
            % called to load data to the output cards
            import NationalInstruments.DAQmx.*
            nsamples = size(scannerOut, 1);
            obj.AOtask{1}.Timing.ConfigureSampleClock('', obj.AOrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, nsamples)
            if ~isempty(obj.laserSyncPort)
                obj.AOtask{1}.Timing.SampleClockTimebaseSource = obj.laserSyncPort;
                obj.AOtask{1}.Timing.SampleClockTimebaseRate = obj.AIrate;
                obj.GateTask.Timing.SampleClockTimebaseSource = obj.laserSyncPort;
                obj.GateTask.Timing.SampleClockTimebaseRate = obj.AIrate;
            else
                obj.AOtask{1}.Timing.SampleClockTimebaseSource = '100MHzTimebase';
                obj.AOtask{1}.Timing.SampleClockTimebaseRate = 100e6;
                obj.GateTask.Timing.SampleClockTimebaseSource = '100MHzTimebase';
                obj.GateTask.Timing.SampleClockTimebaseRate = 100e6;
            end
            obj.AOwriter{1}.WriteMultiSample(false, scannerOut(:, obj.channelOrder{1})');
            obj.GateTaskWriter.WriteMultiSamplePort(false, uint32(scannerOut(:, 4)'>0));
            for iWriter = 2:numel(obj.AOwriter)
                obj.AOtask{iWriter}.Timing.ConfigureSampleClock('PFI7', obj.AOrate, SampleClockActiveEdge.Rising, SampleQuantityMode.ContinuousSamples, nsamples)
                obj.AOwriter{iWriter}.WriteMultiSample(false, scannerOut(:, obj.channelOrder{iWriter})');
            end
        end

        function setupAIlistener(obj, fun, nsamples)
            % sets up a samples acquired listener (execute <fun> every <nsamples> samples)
            import NationalInstruments.DAQmx.*
            buffersize = max([nsamples*2 1000000]);
            buffersize = ceil(buffersize/nsamples)*nsamples; %to make sure buffer size is an integer multiple of nsamples
            obj.AItask.Timing.ConfigureSampleClock(obj.laserSyncPort,obj.AIrate,SampleClockActiveEdge.Rising,SampleQuantityMode.ContinuousSamples,buffersize);
            obj.AItask.EveryNSamplesReadEventInterval = nsamples;
            obj.AIlistener = addlistener(obj.AItask, 'EveryNSamplesRead', @(~, ev) fun(obj.pmtPolarity.*obj.AIreader.ReadInt16(nsamples).int16));
        end

        function start(obj)
            % start AI and AO
            for iTask = [obj.AOtask {obj.AItask} {obj.GateTask}]
                iTask{1}.Start
            end
        end

        function stopAndCleanup(obj, varargin)
            % stop everything and cleanup appropriately
            obj.shutterClose;
            delete(obj.AIlistener)

            for iTask = [{obj.AItask} obj.AOtask {obj.GateTask}]
                iTask{1}.Stop
                iTask{1}.Control(NationalInstruments.DAQmx.TaskAction.Unreserve)
            end

            obj.GateCloseWriter.WriteSingleSampleSingleLine(true, false);

            obj.isScanning = false;
        end

    end %methods

end %classdef
