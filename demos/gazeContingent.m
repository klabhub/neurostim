  [x,y,buttons,focus,valuators,valinfo] = GetMouse(o.cic.window);
                    if buttons(1)
                        o.X = x-o.cic.center(1);
                        o.Y = y-o.cic.center(2);
                    end