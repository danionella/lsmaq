import javax.swing.*;
import javax.swing.table.*;
import java.awt.*;

public class CustomCellEditor extends AbstractCellEditor implements TableCellEditor {
    JTextField textfield = new JTextField();
    JPanel panel = new JPanel(new BorderLayout());
    JButton button = new JButton();
    
    public CustomCellEditor(){
        button.setPreferredSize(new Dimension(15,15));
        button.setText("...");
        panel.add(textfield);
        panel.add(button, BorderLayout.EAST);
    }
    
    // called when editing is completed, returns the new value to be stored in the cell.
    public Object getCellEditorValue() {
        return textfield.getText();
    }
    
    // called when a cell value is edited by the user.
    public Component getTableCellEditorComponent(JTable table, Object value, boolean isSelected, int rowIndex, int vColIndex) {
        textfield.setText((String)value);
        return panel;
    }
    
    // this public function will allow MATLAB to change button properties
    public JButton getButton(){
        return button;
    }
    
    // this public function will allow MATLAB to change textfield properties
    public JTextField getTextField(){
        return textfield;
    }
    
}