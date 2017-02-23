Concentration Room
==================
![Concentration Room](https://raw.githubusercontent.com/pinobatch/croom-nes/master/docs/croomlogo320.png)

A tile matching game for NES by Damian Yerrick

Overview
--------
![Screenshot](https://github.com/pinobatch/croom-nes/blob/master/docs/croom_screenshot01.png?raw=true)

An accident at the biochemical lab has released a neurotoxin,
and you've been quarantined after exposure.  Maintain your
sanity by playing a card-matching game.

The table is littered with 10, 20, 36, 52, or 72 face-down cards.
Flip two cards, and if they show the same emblem, you keep them.
If they don't, flip them back.

System Requirements
-------------------
Concentration Room is for Nintendo Entertainment System and compatible consoles (also called "famiclones"). This version is an NROM-128 (16 KiB PRG, 8 KiB CHR), and it has been tested on a [PowerPak] CompactFlash to NES adapter.
It also works in emulators such as [FCEUX].

[PowerPak]: http://www.retrousb.com/index.php?cPath=24
[FCEUX]: http://fceux.com/

Modes
-----
* 1 Player Story  
  Play solitaire to start to work the toxin out of your system.
  Then defeat other contaminated technicians and children one on one.
* 1 Player Solitaire  
  Select a difficulty level, then try to clear the table without
* 2 Players  
  Two players take turns turning over cards.  They can pass one
  controller back and forth or use one controller each.  If a pair
  doesn't match, the other player presses the A and B Buttons and
  takes a turn. The first player to take half the pairs wins.
* Vs. CPU  
  Like 2 Players, except the second player is controlled by the NES.

Questions
---------
"How long have you been working on this?"

This is actually my third try. The logo and the earliest background sketch date back to 2000. It got held up because I lacked artistic skill on the 16x16 pixel canvas. The second try in 2007 finalized the appearance of the game, and I did some work on the "emblem designer" that will show up in a future release.
In late November 2009, I discovered *[Dian Shi Mali][Waluigious Dian Shi Mali]*,
a [gambling simulator][Wikipedia Dian Shi Mali] for the Famicom (Asian version of the NES) that also uses 16x16 pixel emblems.
After a few hours of [pushing Start to rich][Dian Shi Mali video], I was inspired to create a set of 36 emblems. By then, I was ready to code most of the game in spare time during December 2009.

"Why are you still making games that don't scroll? You're better than that, as I saw in the [President video]."

I saw it as something simple that I could finish fairly quickly in order to push falling block games off the front page of [my web site][Pin Eight].

"GameTek already made two other Concentration games on the NES. Why did you make this one?"

You're referring to *I Can Remember* and *Classic Concentration*. I tried them; their controls are clunky. Neither of them features a full 72-card deck. Neither is [free software], or software that respects users' freedom.

"In vs. modes, why end the game at half the cards matched instead of one more than half?"

Pairs early in a game require more skill to clear, and the last pair requires absolutely no skill.  For example, a 20-card game tied at 4-4 will always end up 6-4.  And at 5-3, the player in the lead likely got more early matches.  So if we award no points for the last pair, the first player to reach half always wins.

"What's that font?"

* The font in the game's logo is called [Wasted Collection]. The font in [Multiboot Menu] for Game Boy Advance was based on it. <a title="Launcher for small programs for Game Boy Advance" href="http://www.pineight.com/gba/#mbmenu">Multiboot Menu</a> was based on it.
* The monospace font for menu text originally appeared in the "Who's Cuter" demo and is based on Apple [Chicago] by Susan Kare.

"Are you a Nazi?"
No, and that's why this game is called Concentration *Room,* not [Concentration Camp][National Lampoon video].

[Waluigious Dian Shi Mali]: http://www.waluigious.com/2008/09/in-which-dian-shi-ma-li.html
[Wikipedia Dian Shi Mali]: https://en.wikipedia.org/wiki/Dian_Shi_Mali
[Dian Shi Mali video]: https://www.youtube.com/watch?v=4s1mAPISOzw
[President video]: https://www.youtube.com/watch?v=GY693NxC9xU
[Pin Eight]: https://pineight.com/
[free software]: https://www.gnu.org/philosophy/free-sw.html
[Wasted Collection]: http://www.windowfonts.com/fonts/wasted-collection.html
[Multiboot Menu]: https://pineight.com/gba/#mbmenu
[Chicago]: http://en.wikipedia.org/wiki/Chicago_%28typeface%29
[National Lampoon video]: http://www.youtube.com/watch?v=cXeHn9k27Iw

Legal
-----
© 2010 Damian Yerrick &lt;croom&#64;pineight.com&gt;

Copying and distribution of this file, with or without modification, are permitted in any medium without royalty provided the copyright notice and this notice are preserved.  This file is offered as-is, without any warranty.

The accompanying program is free software: you can redistribute it and/or modify it under the terms of the [GNU General Public License], version 3 or later. As a special exception, you may copy and distribute exact copies of the program, as published by Damian Yerrick, in iNES or UNIF executable form without source code.

This product is not sponsored or endorsed by Nintendo, Ravensburger, Hasbro, Mattel, Quaker Oats, NBCUniversal, GameTek, or Apple.

[GNU General Public License]: https://www.gnu.org/licenses/gpl.html
