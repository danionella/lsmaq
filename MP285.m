classdef MP285 < handle
    % MP285 - create object to interface with Sutter Instrument Micromanipulator

    properties
        uSteps_per_um  % [x y z] microsteps per micrometer
        hPort
    end

    properties (Dependent = true)
        status
        velocity
    end

    methods
        %% initiation
        function obj = MP285(comport, uSteps_per_um)
            obj.hPort = instrfind('Port', comport);
            if ~isempty(obj.hPort)
                try fclose(obj.hPort); delete(obj.hPort), end
            end
            obj.hPort = serial(comport);
            set(obj.hPort, 'BaudRate', 9200, 'Parity', 'none' , 'Terminator', {'CR', ''}, ...
                'StopBits', 1, 'Timeout', 10, 'Name', 'MP285', 'ErrorFcn', @(varargin) disp('MP285 error!'));
            fopen(obj.hPort);
            if nargin < 2
                uSteps_per_um = [25 25 25];
                warning('defaulting to 25 usteps/um')
            end
            obj.uSteps_per_um = uSteps_per_um;
            obj.getPos;
            obj.velocity = 200;
        end

        % set properties
        function set.velocity(obj, val)
            vel = ['V' typecast(bitset(uint16(val),16,0),'uint8')];
            obj.write(vel);
        end

        % basic control and communication
        function out = flush(obj)
            nBytes = get(obj.hPort, 'BytesAvailable');
            if nBytes > 0
                out = fread(obj.hPort, nBytes);
            else
                out = [];
            end
        end

        function status = write(obj,in)
            obj.flush();
            fwrite(obj.hPort, [in 13]);
            if nargout > 0, status = fread(obj.hPort,1); end
        end

        function status = moveAbs(obj,xyz)
            if nargout > 0
                status = obj.write(['m' obj.toChar(int32(xyz.*obj.uSteps_per_um))]);
            else
                obj.write(['m' obj.toChar(int32(xyz.*obj.uSteps_per_um))]);
            end
        end

        function status = moveRel(obj,xyz) % in microns [x y z]'
            [xyzOld] = obj.getPos;
            % pause(0.05);
            if nargout > 0
                status = obj.moveAbs(xyz + xyzOld);
            else
                obj.moveAbs(xyz + xyzOld);
            end
        end

        function out = get.status(obj) % in microns
            obj.write('s');
            out.flags = dec2binvec(fread(obj.hPort, 1, 'uint8'), 8);
            out.udirXYZ = fread(obj.hPort, 3, 'uint8')';
            out.roe_vari = fread(obj.hPort, 1, 'uint16');
            out.uoffset = fread(obj.hPort, 1, 'uint16');
            out.range = fread(obj.hPort, 1, 'uint16');
            out.pulse = fread(obj.hPort, 1, 'uint16');
            out.uspeed = fread(obj.hPort, 1, 'uint16');
            out.indevice = fread(obj.hPort, 1, 'uint8');
            out.flags_2 = dec2binvec(fread(obj.hPort, 1, 'uint8'), 8);
            out.jumpspd = fread(obj.hPort, 1, 'uint16');
            out.highspd = fread(obj.hPort, 1, 'uint16');
            out.dead = fread(obj.hPort, 1, 'uint16');
            out.watch_dog = fread(obj.hPort, 1, 'uint16');
            out.step_div = fread(obj.hPort, 1, 'uint16');
            out.step_mul = fread(obj.hPort, 1, 'uint16');
            out.xspeed = fread(obj.hPort, 1, 'uint16');
            out.version = fread(obj.hPort, 1, 'uint16');
            obj.flush();
        end

        function [xyz, status] = getPos(obj) % in microns
            obj.write('c');
            xyz = fread(obj.hPort, 3, 'long')' ./ obj.uSteps_per_um;
            if nargout > 1, status = fread(obj.hPort, 1);end
        end
        %
        function delete(obj) % class destructor
            if ~isempty(obj.hPort), fclose(obj.hPort); end
        end

        % Helper functions
        function c = toChar(obj,in)
            c = typecast(in, 'uint8');
        end

    end
end
