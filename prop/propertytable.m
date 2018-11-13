function [pp, pt, ptm, ppc, ds] = propertytable(ds, hF)
%PROPERTYTABLE lauch JIDE-based property grid
%
%   propertytable(ds, hF)
%
%   %ds: dynamicshell object or structure containing properties
%   %hF: figure handle (optional)
%   
%   See also dynamicshell

% see http://undocumentedmatlab.com/blog/advanced-jide-property-grids
% and http://www.jidesoft.com/products/JIDE_Grids_Developer_Guide.pdf
% and http://www.mathworks.com/matlabcentral/fileexchange/38864

%process input arguments
if nargin < 2 || isempty(hF)
    hF = figure; set(hF, 'NumberTitle', 'off', 'Name', inputname(1))
    set(hF, 'ToolBar', 'none', 'MenuBar', 'none')
    pos = get(hF, 'Position'); set(hF, 'Position', [pos(1:2) 200 pos(4)]);
end

%make sure props is a dynamicshell
if ~isa(ds, 'dynamicshell'), ds = dynamicshell(ds); end

%create java objects
tablePropertyArray = javaObjectEDT(java.util.ArrayList);
addChildProps(tablePropertyArray, ds);
ptm = javaObjectEDT(com.jidesoft.grid.PropertyTableModel(tablePropertyArray));
pt = javaObjectEDT(com.jidesoft.grid.PropertyTable(ptm));
pp = javaObjectEDT(com.jidesoft.grid.PropertyPane(pt));

%change appearance
pp.setShowDescription(false)
pp.setShowToolBar(false)
pp.setOrder(2);
pt.expandAll;

%show on screen
figure(hF)
[~, ppc] = javacomponent(pp);
set(ppc, 'Units', 'normalized', 'Position', [0 0 1 1])

%optional: set editors and renderers
cem = com.jidesoft.grid.CellEditorManager(); cem.initDefaultEditor();
cem.registerEditor(java.lang.Boolean(0).getClass, com.jidesoft.grid.BooleanCheckBoxCellEditor);
crm = com.jidesoft.grid.CellRendererManager();
crm.registerRenderer(java.lang.Boolean(0).getClass, com.jidesoft.grid.BooleanCheckBoxCellRenderer)
%ptmh.getProperty('zoom').setEditorContext(com.jidesoft.grid.SpinnerCellEditor.CONTEXT)

% set table change callback
set(ptm, 'PropertyChangeCallback', @TablePropChangeCallback);

    function addChildProps(parent, props)
    %populates the list of com.jidesoft.grid.DefaultProperty objects
        for iFldn = fieldnames(props)'
            val = props.(iFldn{1});
            p = com.jidesoft.grid.DefaultProperty;
            p.setName(iFldn{1});
            p.setType(java.lang.String('').getClass);
            if isstruct(val) || isa(val, 'dynamicshell')
                p.setEditable(false);
                p.setValue('');
                addChildProps(p, val) %creates a sub-branch
            else %single property: update table and attach listener
                setTablePropVal(p, val)
                lh = event.proplistener(props, findprop(props, iFldn{1}), 'PostSet', @(dp, ev) setTablePropVal(p, ev.AffectedObject.(dp.Name)));
                setappdata(hF, 'proplistener', [getappdata(hF, 'proplistener') lh]);
            end
            if isa(parent, 'java.util.ArrayList')
                parent.add(p);
            elseif isa(parent, 'com.jidesoft.grid.DefaultProperty')
                parent.addChild(p);
            end
        end
    end

    function setTablePropVal(p, val)
    %called whenever a table value needs to be updated 
        if exist('pth', 'var') && ~isempty(pth.getCellEditor), pth.getCellEditor.stopCellEditing; end
        if ~(isnumeric(val) || ischar(val) || islogical(val)) %not displayable
            p.setEditable(false);
            p.setValue([strrep(num2str(size(val)), '  ', 'x') class(val)]);
        else %single editable property
            p.setEditable(true);
            p.setValue(mat2str(val));
        end
    end

    function TablePropChangeCallback(model, event)
    %called whenever a property on the table is changed
        propName = event.getPropertyName.toCharArray';
        %if strcmp(propName, 'value'), return, end
        newValue = event.getNewValue;
        oldValue = event.getOldValue;
        prop = model.getProperty(propName);
        try %update dynamicshell object
            subs = strsplit(event.getPropertyName.toCharArray', '.');
            ds = subsasgn(ds, struct('type', '.', 'subs', subs), eval(newValue));            
        catch %in case of error revert to old value
            warning(lasterr)
            prop.setValue(oldValue);
        end
        model.refresh;
    end

end %propertytable

