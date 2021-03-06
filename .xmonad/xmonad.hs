import qualified Data.Map                      as M
import           Data.List                     ( elemIndex )
import           XMonad
import           XMonad.Actions.DynamicWorkspaces
import           XMonad.Actions.DynamicWorkspaceOrder
import           XMonad.Hooks.DynamicLog
import           XMonad.Hooks.EwmhDesktops
import           XMonad.Hooks.ManageDocks
import           XMonad.Hooks.UrgencyHook
import           XMonad.Layout.Accordion
import           XMonad.Layout.LayoutBuilder
import           XMonad.Layout.MultiColumns
import           XMonad.Layout.Renamed
import           XMonad.Layout.ResizableTile
import           XMonad.Layout.PerWorkspace     ( onWorkspace )
import           XMonad.Layout.SimplestFloat
import           XMonad.Layout.ToggleLayouts    ( toggleLayouts )
import           XMonad.Layout.WindowArranger
import           XMonad.Layout.WorkspaceDir
import qualified XMonad.StackSet               as W
import           XMonad.Util.Run                ( spawnPipe )
import           XMonad.Util.EZConfig           ( additionalKeys
                                                , additionalKeysP
                                                )
import           Graphics.X11.ExtraTypes.XF86
import           System.IO
import           System.Exit


-- main = mainXmobar
main = mainDzen

mainDzen = do
    d <-
        spawnPipe
            "dzen2 -dock -p -xs 1 -ta l -h 18 -e 'button3=exit:13;sigusr1=togglehide'"
    spawn $ "conky -c ~/.config/conky/conky_status.lua"
    xmonad $ withUrgencyHook NoUrgencyHook $ myConfig $ dynamicLogWithPP
        defaultPP { ppOutput  = hPutStrLn d
                  , ppTitle   = (" " ++) . dzenColor "green" "" . dzenEscape
                  , ppCurrent = dzenColor "green" "" . pad
                  , ppVisible = dzenColor "yellow" "" . pad
                  , ppHidden  = dzenColor "white" "" . pad
                  , ppUrgent  = dzenColor "red" "" . pad
                  , ppWsSep   = ""
                  , ppSep     = " | "
                  , ppSort    = getSortByOrder
                  }

mainXmobar = do
    xmproc <- spawnPipe "xmobar-top"
    xmonad $ myConfig $ dynamicLogWithPP xmobarPP
        { ppOutput = hPutStrLn xmproc
        , ppTitle  = xmobarColor "green" "" . shorten 180
        }

myConfig lh = ewmh $ def
    { modMask            = myMod
    , terminal           = "alacritty"
    , borderWidth        = 1
    , normalBorderColor  = "#dddddd"
    , focusedBorderColor = "#00ff00"
    , workspaces         = myWorkspaces
    , manageHook         = myManageHook
    , layoutHook         = myLayoutHook
    , handleEventHook    = handleEventHook def
                           <+> docksEventHook
                           <+> fullscreenEventHook
    , logHook            = lh
    , keys               = myKeys
    }

myMod = mod4Mask

myWorkspaces =
    ["work", "web", "chat", "read", "full", "float"]

myManageHook =
    (composeAll . concat $ [[ resource =? r --> doFloat | r <- myFloatApps ]])
        <+> manageDocks
        <+> def
    where myFloatApps = ["Zotero", "pavucontrol", "xmessage"]

myLayoutHook =
    avoidStruts
        $ toggleLayouts simplestFloat
        $ windowArrange
        $ onWorkspace "work"  myWorkLayout
        $ onWorkspace "web"   myWebLayout
        $ onWorkspace "chat"  myChatLayout
        $ onWorkspace "read"  myMediaLayout
        $ onWorkspace "full"  full
        $ onWorkspace "float" simplestFloat
        $ myDefaultLayout
  where
    myWorkLayout =
        workspaceDir "~"
            $   tiled
            ||| columns 1
            ||| full
            ||| tallAcc
    myWebLayout =
        workspaceDir "~/Downloads"
            $   tiled'
            ||| columns 1
            ||| full
            ||| accord
            ||| simplestFloat
    myChatLayout  = tiled ||| columns 1 ||| full
    myMediaLayout = tiled' ||| full ||| simplestFloat
    myDefaultLayout =
        tiled ||| Mirror tiled ||| full ||| columns 1 ||| accord

    full    = renamed [Replace "full"] Full
    accord  = renamed [Replace "accordion"] Accordion
    tiled   = renamed [Replace "tall"]
              $ Tall nmaster delta ratio
    tiled'  = renamed [Replace "tall'"]
              $ Tall nmaster delta (4 / 7)
    nmaster = 1
    delta   = 3 / 100
    ratio   = 1 / 2
    columns n = renamed [Replace "multicol"]
                $ multiCol [nmaster] n delta 0.5
    tallAcc = renamed [Replace "tallacc"]
              $ layoutN 1 (relBox 0 0 0.45 1)
                    (Just $ relBox 0 0 1 1)
                    (Mirror tiled)
                    (layoutAll (relBox 0.45 0 1 1) accord)

dmenu cmd = spawn $ cmd ++ dmenuTheme
    where dmenuTheme = " -nb '#000' -nf '#0f0' -sb '#b31e8d' -sf '#0f0'"

volumeUpdate n =
    spawn $ "pactl set-sink-volume @DEFAULT_SINK@ " ++ sho n ++ "%"
  where
    sho n | n > 0     = "+" ++ show n
          | otherwise = show n

volumeToggle = spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle"

screenGrab focused =
    spawn $ "scrot " ++ filename ++ " -d 1 -e 'sxiv $f'" ++ opts
  where
    (prefix, opts) = if focused then ("window", " -u") else ("screen", "")
    filename       = "~/Pictures/" ++ prefix ++ "_%Y-%m-%d-%H-%M-%S.png"

myFloatArrangeStep = 20

getWorkspacesH :: X [WorkspaceId]
getWorkspacesH = do
    ws <- gets windowset
    return $ map W.tag $ W.hidden ws

getWorkspacesA :: X [WorkspaceId]
getWorkspacesA = do
    ws <- gets windowset
    sort <- getSortByOrder
    return $ map W.tag $ sort $ W.workspaces ws

data IterWorkspacesDir = NextWorkspace | PrevWorkspace deriving(Eq)

getNextWorkspace :: IterWorkspacesDir -> X WorkspaceId
getNextWorkspace dir = do
    ws <- gets windowset
    sort <- getSortByOrder
    let sorted = map W.tag $ sort $ W.workspaces ws
        current = W.currentTag ws
        curIdx = elemIndex current sorted
    return $ case curIdx of
        (Just c) -> sorted !! (moveIt c (length sorted))
        _        -> current
    where
        moveIt c max
            | dir == NextWorkspace = (c + 1) `mod` max
            | dir == PrevWorkspace && c == 0 = max - 1
            | otherwise = c - 1

myKeys conf@(XConfig { XMonad.modMask = modMask }) =
    M.fromList
        $
    -- launching and killing programs
           [ ( (modMask .|. shiftMask, xK_Return)
             , spawn $ XMonad.terminal conf
             ) -- %! Launch terminal
           , ( (modMask .|. shiftMask, xK_c)
             , kill
             ) -- %! Close the focused window
           , ( (modMask, xK_space)
             , sendMessage NextLayout
             ) -- %! Rotate through the available layout algorithms
           , ( (modMask .|. shiftMask, xK_space)
             , setLayout $ XMonad.layoutHook conf
             ) -- %!  Reset the layouts on the current workspace to default
           , ( (modMask, xK_n)
             , refresh
             ) -- %! Resize viewed windows to the correct size

    -- move focus up or down the window stack
           , ( (modMask, xK_Tab)
             , windows W.focusDown
             ) -- %! Move focus to the next window
           , ( (modMask .|. shiftMask, xK_Tab)
             , windows W.focusUp
             ) -- %! Move focus to the previous window
           , ( (modMask, xK_j)
             , windows W.focusDown
             ) -- %! Move focus to the next window
           , ( (modMask, xK_k)
             , windows W.focusUp
             ) -- %! Move focus to the previous window
           , ( (modMask, xK_m)
             , windows W.focusMaster
             ) -- %! Move focus to the master window

    -- modifying the window order
           , ( (modMask, xK_Return)
             , windows W.swapMaster
             ) -- %! Swap the focused window and the master window
           , ( (modMask .|. shiftMask, xK_j)
             , windows W.swapDown
             ) -- %! Swap the focused window with the next window
           , ( (modMask .|. shiftMask, xK_k)
             , windows W.swapUp
             ) -- %! Swap the focused window with the previous window

    -- dynamic workspaces
           , ( (modMask .|. shiftMask, xK_s)
             , addWorkspacePrompt def
             )
           , ( (modMask, xK_s)
             , selectWorkspace def
             )
           , ( (modMask .|. shiftMask, xK_Delete)
             , fmap (filter (`notElem` myWorkspaces)) getWorkspacesH
               >>= (mapM_ removeEmptyWorkspaceByTag)
             ) -- clean up all hidden, empty, temporary workspaces
           , ( (modMask .|. shiftMask, xK_v)
             , withWorkspace def $ windows . W.shift
             )
           , ( (modMask, xK_Page_Up)
             , (getNextWorkspace NextWorkspace) >>= (windows . W.greedyView)
             )
           , ( (modMask, xK_Page_Down)
             , (getNextWorkspace PrevWorkspace) >>= (windows . W.greedyView)
             )

    -- resizing the master/slave ratio
           , ( (modMask, xK_h)
             , sendMessage Shrink
             ) -- %! Shrink the master area
           , ( (modMask, xK_l)
             , sendMessage Expand
             ) -- %! Expand the master area

           , ( (myMod .|. shiftMask, xK_h)
             , sendMessage (IncLayoutN (-1))
             )
           , ( (myMod .|. shiftMask, xK_l)
             , sendMessage (IncLayoutN 1)
             )

    -- floating layer support
           , ( (modMask, xK_t)
             , withFocused $ windows . W.sink
             ) -- %! Push window back into tiling

    -- increase or decrease number of windows in the master area
           , ( (modMask, xK_comma)
             , sendMessage (IncMasterN 1)
             ) -- %! Increment the number of windows in the master area
           , ( (modMask, xK_period)
             , sendMessage (IncMasterN (-1))
             ) -- %! Deincrement the number of windows in the master area
           , ( (myMod .|. shiftMask, xK_z)
             , spawn "xscreensaver-command -lock"
             )
           -- , ((myMod, xK_p), dmenu "dmenu_run")
           -- , ((myMod .|. shiftMask, xK_p), dmenu "dmenu_aliases")
           , ( (myMod, xK_p)
             , spawn "rofi -show drun -modi drun,window,ssh,run -monitor -4"
             )
           , ( (myMod .|. shiftMask, xK_p)
             , spawn "~/.scripts/rofi_aliases -monitor -4"
             )
           , ( (myMod, xK_slash)
             , spawn "rofi -monitor -4 -show window -modi window,windowcd"
             )
           -- , ( (myMod .|. shiftMask, xK_h)
           --   , spawn "xdotool mousemove --window `xdotool getwindowfocus` 20 20"
           --   )
           , ((0 .|. shiftMask, xF86XK_MonBrightnessUp), spawn "lux -a 10%")
           , ((0 .|. shiftMask, xF86XK_MonBrightnessDown), spawn "lux -s 10%")
           , ((0, xF86XK_MonBrightnessUp), spawn "lux -a 5%")
           , ((0, xF86XK_MonBrightnessDown), spawn "lux -s 5%")
           , ((0, xF86XK_AudioLowerVolume), volumeUpdate (-10))
           , ((shiftMask, xF86XK_AudioLowerVolume), volumeUpdate (-1))
           , ((0, xF86XK_AudioRaiseVolume), volumeUpdate 10)
           , ((shiftMask, xF86XK_AudioRaiseVolume), volumeUpdate 1)
           , ((0, xF86XK_AudioMute), volumeToggle)
           , ((0 .|. shiftMask, xF86XK_AudioMute), spawn "pavucontrol")
           , ((0, xK_Print), screenGrab False)
           , ( (myMod, xK_Print)
             , screenGrab True
             )

    -- resize and move loating windows with keyboard
           , ( (myMod .|. controlMask, xK_Left)
             , sendMessage (MoveLeft myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask, xK_Right)
             , sendMessage (MoveRight myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask, xK_Down)
             , sendMessage (MoveDown myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask, xK_Up)
             , sendMessage (MoveUp myFloatArrangeStep)
             )
           , ( (myMod .|. shiftMask, xK_Left)
             , sendMessage (IncreaseLeft myFloatArrangeStep)
             )
           , ( (myMod .|. shiftMask, xK_Right)
             , sendMessage (IncreaseRight myFloatArrangeStep)
             )
           , ( (myMod .|. shiftMask, xK_Down)
             , sendMessage (IncreaseDown myFloatArrangeStep)
             )
           , ( (myMod .|. shiftMask, xK_Up)
             , sendMessage (IncreaseUp myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask .|. shiftMask, xK_Left)
             , sendMessage (DecreaseLeft myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask .|. shiftMask, xK_Right)
             , sendMessage (DecreaseRight myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask .|. shiftMask, xK_Down)
             , sendMessage (DecreaseDown myFloatArrangeStep)
             )
           , ( (myMod .|. controlMask .|. shiftMask, xK_Up)
             , sendMessage (DecreaseUp myFloatArrangeStep)
             )

    -- quit, or restart
           , ( (modMask .|. shiftMask, xK_q)
             , io (exitWith ExitSuccess)
             ) -- %! Quit xmonad
           , ( (myMod, xK_q)
             , spawn "killall conky dzen2; xmonad --recompile; xmonad --restart"
             )
           , ( (modMask .|. shiftMask, xK_slash)
             , helpCommand
             ) -- %! Run xmessage with a summary of the default keybindings (useful for beginners)
    -- repeat the binding for non-American layout keyboards
           , ((modMask, xK_question), helpCommand) -- %! Run xmessage with a summary of the default keybindings (useful for beginners)
           ]
        ++
    -- mod-[1..9] %! Switch to workspace N
    -- mod-shift-[1..9] %! Move client to workspace N
           [ ((m .|. modMask, k), windows $ f i)
           | (i, k) <- zip (XMonad.workspaces conf) [xK_1 .. xK_9]
           , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
           ]
        ++
           [ ((m .|. modMask, k), getWorkspacesA >>= (return . (!! i)) >>= (windows . f))
           | (i, k) <- drop (length $ workspaces conf) $ zip [0 ..] [xK_1 .. xK_9]
           , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
           ]
        ++
    -- mod-{w,e,r} %! Switch to physical/Xinerama screens 1, 2, or 3
    -- mod-shift-{w,e,r} %! Move client to screen 1, 2, or 3
           [ ( (m .|. modMask, key)
             , screenWorkspace sc >>= flip whenJust (windows . f)
             )
           | (key, sc) <- zip [xK_w, xK_e, xK_r] [0 ..]
           , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]
           ]
  where
    helpCommand =
        spawn
            $ "fortune computers perl linux fortunes humorists | "
            ++ "cowsay -f ghostbusters | xmessage -bg black -fg green3 -default okay -file -"
