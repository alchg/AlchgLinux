import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, GdkPixbuf, Gdk
import sys
import os
import subprocess  # For command execution

class ImageViewer:
    def __init__(self, directory_path):
        self.directory_path = directory_path
        self.image_files = self._get_image_files()
        # Define the desired display size (width, height)
        self.IMAGE_SIZE = 160
        self.window = None
        self.selected_path = None  # Variable to hold the currently selected path

    def _get_image_files(self):
        """Scans the directory for common image file extensions."""
        supported_extensions = ('.png', '.jpg', '.jpeg', '.gif', '.bmp')
        image_paths = []
        try:
            for filename in os.listdir(self.directory_path):
                if filename.lower().endswith(supported_extensions):
                    full_path = os.path.join(self.directory_path, filename)
                    image_paths.append(full_path)
            # Sort files for consistent viewing order
            return sorted(image_paths)
        except FileNotFoundError:
            print(f"Error: Directory not found at {self.directory_path}")
            sys.exit(1)

    def build_ui(self):
        """Sets up the GTK window and image display."""
        window = Gtk.Window(title="Image Viewer")
        window.set_default_size(800, 600)
        window.connect("destroy", Gtk.main_quit)

        # Main container for scrolling content (Images)
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        
        # Change FlowBox selection mode to SINGLE (single selection)
        image_container = Gtk.FlowBox()
        image_container.set_valign(Gtk.Align.START)
        image_container.set_max_children_per_line(30)
        image_container.set_selection_mode(Gtk.SelectionMode.SINGLE) 
        
        # Connect the event for when an item in FlowBox is selected/activated
        image_container.connect("child-activated", self._on_image_activated)
        
        # Add signal to update path even when selection changes (e.g., on click)
        image_container.connect("selected-children-changed", self._on_selection_changed)

        # Connect key press handler for Enter/Return on the FlowBox itself
        image_container.connect("key-press-event", self._on_flowbox_key_press)
        
        # Set spacing (padding) between images
        image_container.set_row_spacing(10)
        image_container.set_column_spacing(10)

        self._display_images(image_container)
        scrolled_window.add(image_container)
        
        # Initial selection logic
        children = image_container.get_children()
        if children:
            # 1. Get the first child (image) and set it to selected state
            first_child = children[0]
            image_container.select_child(first_child)
            # 2. Keep the path of the initially selected image
            self.selected_path = getattr(first_child, "image_path", None)
        
        # Create a horizontal box (HBox) for buttons
        button_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_hbox.set_halign(Gtk.Align.CENTER) # Aligned to center
        
        # Create and connect the Execute button
        execute_button = Gtk.Button(label="Apply")
        execute_button.connect("clicked", self._on_execute_clicked)
        
        # Create and connect the Exit button
        exit_button = Gtk.Button(label="Exit")
        exit_button.connect("clicked", Gtk.main_quit)
        
        # Add buttons to the horizontal box
        button_hbox.pack_start(execute_button, False, False, 0)
        button_hbox.pack_start(exit_button, False, False, 0)
        
        # Use a vertical box to stack scrolled content and buttons
        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_vbox.pack_start(scrolled_window, True, True, 0)
        main_vbox.pack_start(button_hbox, False, False, 5) # Add button box to the bottom

        window.add(main_vbox)
        
        # Store references as instance variables for easy access
        self.window = window 

        return window

    def _display_images(self, container):
        """Loads and displays all images into the provided flowbox container."""
        if not self.image_files:
            label = Gtk.Label(label="No supported images found in this directory.")
            container.add(label)
            return

        print(f"Found {len(self.image_files)} images to display.")
        
        for path in self.image_files:
            try:
                # Create a widget to hold the image
                image_wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
                
                # Load and scale image maintaining aspect ratio safely
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, self.IMAGE_SIZE, 120, True)
                image_widget = Gtk.Image.new_from_pixbuf(pixbuf)
                
                # Only add the image widget to the wrapper
                image_wrapper.pack_start(image_widget, True, True, 0)

                # Add the wrapper directly to FlowBox
                container.add(image_wrapper)
                
                # Attach data (path) to the child widget so it can be retrieved later
                child_widget = container.get_children()[-1]
                child_widget.image_path = path

            except Exception as e:
                print(f"Error loading image {os.path.basename(path)}: {e}")

    def _on_flowbox_key_press(self, widget, event):
        """Handles key press events on the FlowBox container itself."""
        # Check if the pressed key is Enter/Return (Gdk.Key.Return or Gdk.Key.KP_Enter)
        if event.keyval == Gdk.KEY_Return or event.keyval == Gdk.KEY_KP_Enter:
            self._on_execute_clicked(None) # Execute the command, passing None as button argument
            return True  # Consume the event
        return False

    # Countermeasures for keyboard navigation or single click selection changes
    def _on_selection_changed(self, box):
        """Callback for when the selection changes (e.g. arrow keys or single click)."""
        selected_children = box.get_selected_children()
        if selected_children:
            self.selected_path = getattr(selected_children[0], "image_path", None)

    def _on_image_activated(self, box, child):
        """Callback function executed when an image child is selected/activated."""
        # Store the selected path
        path = getattr(child, "image_path", None)
        self.selected_path = path 

    # Handler for the Execute button click
    def _on_execute_clicked(self, button):
        """Executes the 'file' command on the currently selected image."""
        if not self.selected_path:
            print("Warning: Please select an image first.")
            return

        image_name = os.path.basename(self.selected_path)
        print(f"\n--- Applying wallpaper for: {image_name} ---")
        try:
            # 1. Kill any existing swaybg processes
            subprocess.run(["pkill", "swaybg"], check=False)

            # 2. Execute the 'file' command asynchronously
            print("Launching background process...")
            try:
                subprocess.Popen(
                    ["swaybg", "-i", self.selected_path, "-m", "stretch"], 
                    stdout=subprocess.DEVNULL, # Redirect output to prevent blocking/spamming console
                    stderr=subprocess.DEVNULL
                )
                print("Wallpaper set successfully.")
            except FileNotFoundError:
                 print("Error: swaybg command not found. Is it installed and in PATH?")

        except Exception as e:
            # Catch any unexpected errors during the cleanup or launch phase
            print(f"An unexpected error occurred during execution setup: {e}")


def main():
    """Main entry point for the application."""
    if len(sys.argv) != 2:
        print("Usage: python image-viewer.py <directory_path>")
        sys.exit(1)

    directory_path = sys.argv[1]
    
    # Check if the path exists and is a directory
    if not os.path.isdir(directory_path):
        print(f"Error: The provided path '{directory_path}' is not a valid directory.")
        sys.exit(1)

    viewer = ImageViewer(directory_path)
    window = viewer.build_ui()
    
    # Show all widgets and start the GTK main loop
    window.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
