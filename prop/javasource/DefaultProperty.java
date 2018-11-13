import com.jidesoft.swing.JideSwingUtilities;
public class DefaultProperty extends com.jidesoft.grid.Property

{
    
    private Object c;
    
    public DefaultProperty(){
        c = 0;
    }
    
    public void setValue(Object object) {
        Object object_0_ = c;
        if (!object_0_.equals(object)){
            c = object;
            firePropertyChange("value", object_0_, c);
        }
    }
    
    public Object getValue() {
        return c;
    }
    
    public boolean hasValue() {
        return true;
    }
}