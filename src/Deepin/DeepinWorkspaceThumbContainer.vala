//
//  Copyright (C) 2014 Deepin, Inc.
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Clutter;
using Meta;

namespace Gala
{
	/**
	 * Will be put at end of workspace thumbnail list in DeepinMultitaskingView if number less than
	 * MAX_WORKSPACE_NUM.
	 */
	class DeepinWorkspaceAddButton : DeepinCssStaticActor
	{
		const double PLUS_SIZE = 32.0;
		const double PLUS_LINE_WIDTH = 2.0;

		public DeepinWorkspaceAddButton ()
		{
			base ("deepin-workspace-add-button");

			(content as Canvas).draw.connect (on_draw_content);
		}

		bool on_draw_content (Cairo.Context cr, int width, int height)
		{
			// draw tha plus button
			cr.move_to (width / 2 - PLUS_SIZE / 2, height / 2);
			cr.line_to (width / 2 + PLUS_SIZE / 2, height / 2);

			cr.move_to (width / 2, height / 2 - PLUS_SIZE / 2);
			cr.line_to (width / 2, height / 2 + PLUS_SIZE / 2);

			cr.set_line_width (PLUS_LINE_WIDTH);
			cr.set_source_rgba (0.5, 0.5, 0.5, 1.0);
			cr.stroke_preserve ();

			return false;
		}
	}

	/**
	 * This class contains the DeepinWorkspaceThumbClone which placed in the top of multitaskingview
	 * and will take care of displaying actors for inserting windows between the groups once
	 * implemented.
	 */
	public class DeepinWorkspaceThumbContainer : Actor
	{
		/**
		 * The percent value between thumbnail workspace clone's width and monitor's width.
		 */
		public const float WORKSPACE_WIDTH_PERCENT = 0.12f;

		public const int CHILD_FADE_DURATION = 400;
		// public const int CHILD_FADE_DURATION = 1500;// TODO: test
		public const AnimationMode CHILD_FADE_MODE = AnimationMode.EASE_OUT_QUAD;

		/**
		 * The percent value between distance of thumbnail workspace clones and monitor's width.
		 */
		const float SPACING_PERCENT = 0.02f;

		const int LAYOUT_DURATION = 800;

		public Screen screen { get; construct; }

		Actor plus_button;

		int new_workspace_index_manually = -1;

		public DeepinWorkspaceThumbContainer (Screen screen)
		{
			Object (screen: screen);

			plus_button = new DeepinWorkspaceAddButton ();
			plus_button.reactive = true;
			plus_button.set_pivot_point (0.5f, 0.5f);
			plus_button.button_press_event.connect (() => {
				append_new_workspace ();
				return false;
			});

			append_plus_button ();
		}

		public void append_new_workspace ()
		{
			DeepinUtils.start_fade_out_animation (plus_button, CHILD_FADE_DURATION, CHILD_FADE_MODE,
												  () => {
			 	remove_child (plus_button);
				new_workspace_index_manually = Prefs.get_num_workspaces ();
				DeepinUtils.append_new_workspace (screen);
			});
		}

		public void add_workspace (DeepinWorkspaceThumbClone workspace_clone)
		{
			var index = workspace_clone.workspace.index ();

			// TODO: animation relayout
			workspace_clone.save_easing_state ();
			workspace_clone.set_easing_duration (0);
			place_child (workspace_clone, index);
			workspace_clone.restore_easing_state ();

			insert_child_at_index (workspace_clone, index);

			workspace_clone.start_fade_in_animation ();
			workspace_clone.thumb_clone.transitions_completed.connect (append_plus_button);

			if (workspace_clone.workspace.index () == new_workspace_index_manually) {
				workspace_clone.workspace_name.grab_key_focus_for_name ();
				new_workspace_index_manually = -1;
			}

			relayout ();
		}

		public void remove_workspace (DeepinWorkspaceThumbClone workspace_clone)
		{
			remove_child (workspace_clone);

			// TODO:
			append_plus_button ();

			// Prevent other workspaces' original name to be reset, so here set
			// them to gsettings again.
			foreach (var child in get_children ()) {
				if (child is DeepinWorkspaceThumbClone) {
					(child as DeepinWorkspaceThumbClone).workspace_name.set_workspace_name ();
				}
			}

			relayout ();
		}
		// TODO:
		// void do_remove_workspace (DeepinWorkspaceThumbClone workspace_clone)
		// {
		// 	remove_child (workspace_clone);

		// 	// TODO:
		// 	append_plus_button ();

		// 	// Prevent other workspaces' original name to be reset, so here set
		// 	// them to gsettings again.
		// 	foreach (var child in get_children ()) {
		// 		if (child is DeepinWorkspaceThumbClone) {
		// 			(child as DeepinWorkspaceThumbClone).workspace_name.set_workspace_name ();
		// 		}
		// 	}

		// 	relayout ();
		// }

		public void relayout ()
		{
			var i = 0;
			foreach (var child in get_children ()) {
				place_child (child, i);
				i++;

				if (child is DeepinWorkspaceThumbClone) {
					(child as DeepinWorkspaceThumbClone).workspace_name.get_workspace_name ();
				}
			}
		}

		/**
		 * Make plus button visible if workspace number less than MAX_WORKSPACE_NUM.
		 */
		void append_plus_button ()
		{
			if (Prefs.get_num_workspaces () < WindowManagerGala.MAX_WORKSPACE_NUM &&
				!contains (plus_button)) {
				place_child (plus_button, get_n_children ());
				insert_child_at_index (plus_button, get_n_children ());
				DeepinUtils.start_fade_in_animation (plus_button, CHILD_FADE_DURATION, CHILD_FADE_MODE);
			}
		}

		// TODO: remove
		// void remove_plus_button ()
		// {
		// 	if (contains (plus_button)) {
		// 		start_child_remove_animation (plus_button);
		// 		plus_button.transitions_completed.connect (() => {
		// 			remove_child (plus_button);
		// 			relayout ();
		// 		});
		// 	}
		// }

		public static void get_prefer_thumb_size (Screen screen, out float width, out float height)
		{
			var monitor_geom = DeepinUtils.get_primary_monitor_geometry (screen);

			// calculate monitor width height ratio
			float monitor_whr = (float)monitor_geom.height / monitor_geom.width;

			width = monitor_geom.width * WORKSPACE_WIDTH_PERCENT;
			height = width * monitor_whr;
		}

		public static ActorBox get_child_layout_box (Screen screen, int index,
													 bool is_thumb_clone = false)
		{
			var monitor_geom = DeepinUtils.get_primary_monitor_geometry (screen);

			var box = ActorBox ();

			float child_x = 0, child_y = 0;
			float child_width = 0, child_height = 0;
			float child_spacing = monitor_geom.width * SPACING_PERCENT;

			get_prefer_thumb_size (screen, out child_width, out child_height);
			child_x = (child_width + child_spacing) * index;

			// for DeepinWorkspaceThumbClone, will plus workspace name field's height
			if (is_thumb_clone) {
				child_height += DeepinWorkspaceThumbClone.WORKSPACE_NAME_DISTANCE +
								DeepinWorkspaceNameField.WORKSPACE_NAME_HEIGHT;
			}

			box.set_size (child_width, child_height);
			box.set_origin (child_x, child_y);

			return box;
		}

		void place_child (Actor child, int index, bool animate = true)
		{
			ActorBox child_box = get_child_layout_box (screen, index,
													   child is DeepinWorkspaceThumbClone);
			child.width = child_box.get_width ();
			child.height = child_box.get_height ();

			if (animate) {
				var position = Point.alloc ();
				position.x = child_box.get_x ();
				position.y = child_box.get_y ();
				var position_value = new GLib.Value (typeof (Point));
				position_value.set_boxed (position);
				DeepinUtils.start_animation_group (child, "thumb-workspace-slot", LAYOUT_DURATION,
												   DeepinUtils.clutter_set_mode_bezier_out_back,
												   "position", &position_value);
			} else {
				child.x = child_box.get_x ();
				child.y = child_box.get_y ();
			}
		}
	}
}
