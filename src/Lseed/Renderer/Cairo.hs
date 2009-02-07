module Lseed.Renderer.Cairo where

import Graphics.UI.Gtk hiding (fill)
import Graphics.Rendering.Cairo
import Control.Monad
import Control.Concurrent
import Data.IORef
import Lseed.Data
import Lseed.Constants
import Lseed.Geometry
import Text.Printf

initRenderer :: IO (Garden -> IO ())
initRenderer = do
	initGUI

	-- global renderer state
	currentGardenRef <- newIORef []

	-- widgets
	canvas <- drawingAreaNew

	window <- windowNew
	set window [windowDefaultWidth := 800, windowDefaultHeight := 600,
	      containerChild := canvas, containerBorderWidth := 0]
	widgetShowAll window

	-- Make gtk and haskell threading compatible
	timeoutAdd (yield >> return True) 50
	
	-- a thread for our GUI
	forkIO $ mainGUI

	-- The actual drawing function
	onExpose canvas (\e -> do garden <- readIORef currentGardenRef
				  dwin <- widgetGetDrawWindow canvas
				  (w,h) <- drawableGetSize dwin
				  renderWithDrawable dwin $ do
					-- Set up coordinates
					translate 0 (fromIntegral h)
					scale 1 (-1)
					scale (fromIntegral w) (fromIntegral (w))
					translate 0 groundLevel
					
					setLineWidth stipeWidth
					render garden
		                  return (eventSent e))

	return $ \garden -> do
		writeIORef currentGardenRef garden
		widgetQueueDraw canvas

render :: Garden -> Render ()
render garden = do
	renderGround
	-- mapM_ renderLightedLine (lightenLines (pi/3) (gardenToLines garden))
	mapM_ renderLightedPoly (lightPolygons (pi/3) (gardenToLines garden))
	-- mapM_ renderLine (gardenToLines garden)
	mapM_ (renderPlanted) garden

	mapM_ (renderInfo) (totalLight (pi/3) (gardenToLines garden))

renderPlanted :: Planted -> Render ()
renderPlanted planted = preserve $ do
	translate (plantPosition planted) 0
	setSourceRGB 0 0.8 0
	renderPlant (phenotype planted)

renderPlant :: Plant -> Render ()	
renderPlant Bud = do
	arc 0 0 budSize 0 (2*pi)
	fill
renderPlant (Stipe len p) = do
	moveTo 0 0
	lineTo 0 (len * stipeLength)
	stroke
	translate 0 (len * stipeLength)
	renderPlant p
renderPlant (Fork angle p1 p2) = do
	preserve $ rotate angle >> renderPlant p1
	renderPlant p2
		
renderLine (l@((x1,y1),(x2,y2)), _) = do
	setSourceRGB 0 1 0 
	setLineWidth (0.5*stipeWidth)
	moveTo x1 y1
	lineTo x2 y2
	stroke
	
renderLightedLine (l@((x1,y1),(x2,y2)), _, intensity) = do
	moveTo x1 y1
	lineTo x2 y2
	let normalized = intensity / lineLength l
	when (normalized > 0) $ do
		liftIO $ print normalized
		setLineWidth (3*stipeWidth)
		setSourceRGBA 1 1 0 normalized
		strokePreserve
	setSourceRGB 0 1 0 
	setLineWidth (0.5*stipeWidth)
	stroke
	
renderLightedPoly ((x1,y1),(x2,y2),(x3,y3),(x4,y4), intensity) = do
	when (intensity > 0) $ do
		moveTo x1 y1
		lineTo x2 y2
		lineTo x3 y3
		lineTo x4 y4
		closePath
		setSourceRGB 0 0 intensity
		fill

renderInfo (x,amount) = do
	let text = printf "%.2f" amount
	preserve $ do
		scale 1 (-1)
		setSourceRGB 0 0 0
		setFontSize (groundLevel/2)
		moveTo x (0.75*groundLevel)
		showText text

renderGround :: Render ()
renderGround = do
	-- Clear Background
	rectangle 0 0 1 100
	setSourceRGB  0 0 1
	fill
	setSourceRGB (140/255) (80/255) (21/255)
	rectangle 0 0 1 (-groundLevel)
        fill

-- | Wrapper that calls 'save' and 'restore' before and after the argument
preserve :: Render () -> Render ()
preserve r = save >> r >> restore
