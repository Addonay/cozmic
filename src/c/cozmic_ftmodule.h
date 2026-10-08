/* FreeType module list for cozmic's bundled build: TrueType/CFF drivers
 * (plus the PostScript helpers CFF needs), the sfnt table loader, the
 * autohinter for unhinted faces, and the anti-aliased renderer. Selected via
 * -DFT_CONFIG_MODULES_H="<cozmic_ftmodule.h>" in build.zig. */
FT_USE_MODULE( FT_Module_Class, autofit_module_class )
FT_USE_MODULE( FT_Driver_ClassRec, tt_driver_class )
FT_USE_MODULE( FT_Driver_ClassRec, cff_driver_class )
FT_USE_MODULE( FT_Module_Class, psaux_module_class )
FT_USE_MODULE( FT_Module_Class, psnames_module_class )
FT_USE_MODULE( FT_Module_Class, pshinter_module_class )
FT_USE_MODULE( FT_Module_Class, sfnt_module_class )
FT_USE_MODULE( FT_Renderer_Class, ft_smooth_renderer_class )
