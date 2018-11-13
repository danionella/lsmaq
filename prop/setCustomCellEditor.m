function setCustomCellEditor(ptmh, name, fDialog)
%SETCUSTOMCELLEDITOR set a custom cell editor
%   setCustomCellEditor(dp, fDialog)
%   Sets a custom cell editor for a property in inspectProps
%       <ptmh>      Property table model handle object
%       <name>      String describing the property name
%       <fDialog>   Function handle for editor dialog. This function will
%                   be called when button is pressed. Arguments: dp, button
%
%   Example:
%       [pph pth ptmh ppc] = inspectProps(prop);  
%       setCustomCellEditor(ptmh, 'dirName', @(dp, button) dp.setValue(['''', uigetdir, ''''))
%
%   See also inspectProps, struct2ref

%   Revision history:
%   071101: created, BJ

warning off, javaaddpath(fileparts(mfilename('fullpath'))), warning on

dp = ptmh.findProperty(name); %DefaultProperty java-object

if ~dp.getType.equals(java.lang.String('').getClass)
    error('can only set custom cell editor for Strings')
end

ec = com.jidesoft.grid.EditorContext(getTempName);
cce = CustomCellEditor;
cem = com.jidesoft.grid.CellEditorManager();
    cem.initDefaultEditor;
    cem.registerEditor(dp.getType, cce, ec);

dp.setEditorContext(ec);

button = handle(cce.getButton, 'callbackProperties');
set(button, 'MouseClickedCallback', @callbackWrapper)

    function callbackWrapper(button, event)
        cce.stopCellEditing;
        fDialog(dp, button);
        ptmh.fireTableDataChanged;
    end

    function tempName = getTempName
        tempName = sprintf('tmp%015.0f', rand(1) * 10^15);
    end

end