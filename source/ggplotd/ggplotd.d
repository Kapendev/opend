module ggplotd.ggplotd;

import cconfig = cairo.c.config;
import cpdf = cairo.pdf;
import csvg = cairo.svg;
import cairo = cairo;

import ggplotd.aes;
import ggplotd.axes;
import ggplotd.colour;
import ggplotd.geom;
import ggplotd.bounds;
import ggplotd.scale;

version (unittest)
{
    import dunit.toolkit;
}

private auto createEmptySurface( string fname, int width, int height )
{
    cairo.Surface surface;

    static if (cconfig.CAIRO_HAS_PDF_SURFACE)
        {
        if (fname[$ - 3 .. $] == "pdf")
            {
            surface = new cpdf.PDFSurface(fname, width, height);
        }
    }
    else
        {
        if (fname[$ - 3 .. $] == "pdf")
            assert(0, "PDF support not enabled by cairoD");
    }
    static if (cconfig.CAIRO_HAS_SVG_SURFACE)
        {
        if (fname[$ - 3 .. $] == "svg")
            {
            surface = new csvg.SVGSurface(fname, width, height);
        }
    }
    else
    {
        if (fname[$ - 3 .. $] == "svg")
            assert(0, "SVG support not enabled by cairoD");
    }
    if (fname[$ - 3 .. $] == "png")
    {
        surface = new cairo.ImageSurface(cairo.Format.CAIRO_FORMAT_ARGB32, width, height);
    }

    auto backcontext = cairo.Context(surface);
    backcontext.setSourceRGB(1, 1, 1);
    backcontext.rectangle(0, 0, width, height);
    backcontext.fill();

    return surface;
}

private alias ScaleType = 
    cairo.Context delegate(cairo.Context context, Bounds bounds);

auto drawGeom( Geom geom, ref cairo.Surface surface,
    ColourMap colourMap, ScaleType scaleFunction, in Bounds bounds, 
    in Margins margins, int width, int height, bool mask = true )
{
    cairo.Context context;
    if (mask) {
        auto plotSurface = cairo.Surface.createForRectangle(surface,
            cairo.Rectangle!double(margins.left, margins.top,
            width - (margins.left+margins.right), 
            height - (margins.top+margins.bottom)));
        context = cairo.Context(plotSurface);
    } else {
        context = cairo.Context(surface);
        context.translate(margins.left, margins.top);
    }
    auto col = colourMap(geom.colour);
    import cairo.cairo : RGBA;
    context.setSourceRGBA(RGBA(col.red, col.green, col.blue, geom.alpha));
    context = scaleFunction(context, bounds);
    context = geom.draw(context);
    context.identityMatrix();
    context.stroke();
    return surface;
}

///
struct Margins
{
    size_t left = 50; ///
    size_t right = 20; ///
    size_t bottom = 50; ///
    size_t top = 20; ///
}

///
struct GGPlotD
{
    Geom[] geomRange;

    XAxis xaxis;
    YAxis yaxis;

    Margins margins;

    ScaleType scaleFunction;

    ///
    void save( string fname, int width = 470, int height = 470 )
    {
        bool pngWrite = false;
        auto surface = createEmptySurface( fname, width, height );

        if (fname[$ - 3 .. $] == "png")
        {
            pngWrite = true;
        }

        if (!initScale)
            scaleFunction = scale( width - (margins.left+margins.right), 
            height - (margins.bottom+margins.top) ); // This needs to be removed later
        import std.range : front;

        AdaptiveBounds bounds;
        typeof(geomRange.front.colour)[] colourIDs;
        auto xAxisTicks = geomRange.front.xTickLabels;
        auto yAxisTicks = geomRange.front.yTickLabels;

        foreach (geom; geomRange)
        {
            bounds.adapt(geom.bounds);
            colourIDs ~= geom.colour;
            xAxisTicks ~= geom.xTickLabels;
            yAxisTicks ~= geom.xTickLabels;
        }

        auto colourMap = createColourMap(colourIDs);

        // Axis
        import std.algorithm : sort, uniq;
        import std.range : chain;
        import std.array : array;
        import ggplotd.axes;

        if (initialized(xaxis))
        {
            bounds.min_x = xaxis.min;
            bounds.max_x = xaxis.max;
        }

        if (initialized(yaxis))
        {
            bounds.min_y = yaxis.min;
            bounds.max_y = yaxis.max;
        }

        auto sortedAxisTicks = xAxisTicks.sort().uniq.array;

        auto aesX = axisAes("x", bounds.min_x, bounds.max_x, bounds.min_y);

        auto aesY = axisAes("y", bounds.min_y, bounds.max_y, bounds.min_x);

        auto gR = chain(geomAxis(aesX, 10.0*bounds.height / height, xaxis.label), geomAxis(aesY, 10.0*bounds.width / width, yaxis.label));

        // Plot axis 
        foreach (geom; gR)
        {
            surface = geom.drawGeom( surface,
                colourMap, scaleFunction, bounds, 
                margins, width, height, false );
        }

        // Plot geomRange
        foreach (geom; geomRange)
        {
            surface = geom.drawGeom( surface,
                colourMap, scaleFunction, bounds, 
                margins, width, height );
        }
 
        if (pngWrite)
            (cast(cairo.ImageSurface)(surface)).writeToPNG(fname);
    }

    ///
    ref GGPlotD opBinary(string op, T)(T rhs)
    {
        static if (op == "+")
        {
            static if (is(ElementType!T==Geom))
            {
                import std.array : array;
                geomRange ~= rhs.array;
            }
            static if (is(T==ScaleType))
            {
                initScale = true;
                scaleFunction = rhs;
            }
            static if (is(T==XAxisFunction))
            {
                xaxis = rhs( xaxis );
            }
            static if (is(T==YAxisFunction))
            {
                yaxis = rhs( yaxis );
            }
            static if (is(T==Margins))
            {
                margins = rhs;
            }
            return this;
        }
    }

    private:
        bool initScale = false;
}

///
unittest
{
    auto aes = Aes!(string[], "x", string[], "y", string[], "colour")(["a",
        "b", "c", "b"], ["a", "b", "b", "a"], ["b", "b", "b", "b"]);
    auto gg = GGPlotD();
    gg + geomLine(aes) + scale();
    gg.save( "test6.png");
}

///
unittest
{
    import std.array : array;
    import std.math : sqrt;
    import std.algorithm : map;
    import std.range : repeat, iota;
    import std.random : uniform;
    // Generate some noisy data with reducing width
    auto f = (double x) { return x/(1+x); };
    auto width = (double x) { return sqrt(0.1/(1+x)); };
    auto xs = iota( 0, 10, 0.1 ).array;

    auto ysfit = xs.map!((x) => f(x));
    auto ysnoise = xs.map!((x) => f(x) + uniform(-width(x),width(x))).array;

    auto aes = Aes!(typeof(xs), "x",
        typeof(ysnoise), "y", string[], "colour" )( xs, ysnoise, ("a").repeat(xs.length).array );
    auto gg = GGPlotD() + geomPoint( aes );
    gg + geomLine( Aes!(typeof(xs), "x",
        typeof(ysfit), "y" )( xs, ysfit ) );

    //  
    auto ys2fit = xs.map!((x) => 1-f(x));
    auto ys2noise = xs.map!((x) => 1-f(x) + uniform(-width(x),width(x))).array;

    gg + geomLine( Aes!(typeof(xs), "x", typeof(ys2fit), "y" )( xs,
        ys2fit) ); 
    gg + geomPoint( Aes!(typeof(xs), "x", typeof(ys2noise), "y", string[],
        "colour" )( xs, ys2noise, ("b").repeat(xs.length).array) );

    gg.save( "noise.png" );
}

///
unittest
{
    import std.array : array;
    import std.algorithm : map;
    import std.range : repeat, iota;
    import std.random : uniform;
    auto xs = iota(0,25,1).map!((x) => uniform(0.0,5)+uniform(0.0,5)).array;
    auto aes = Aes!(typeof(xs), "x")( xs );
    auto gg = GGPlotD() + geomHist( aes );

    auto ys = (0.0).repeat( xs.length ).array;
    auto aesPs = aes.merge( Aes!(double[], "y", double[], "colour" )
        ( ys, ys ) );
    gg + geomPoint( aesPs );

    gg.save( "hist.png" );
}

///
unittest
{
    import std.array : array;
    import std.math : sqrt;
    import std.algorithm : map;
    import std.range : iota;
    // Generate some noisy data with reducing width
    auto f = (double x) { return x/(1+x); };
    auto width = (double x) { return sqrt(0.1/(1+x)); };
    auto xs = iota( 0, 10, 0.1 ).array;

    auto ysfit = xs.map!((x) => f(x)).array;

    auto gg = GGPlotD() + geomLine( Aes!(typeof(xs), "x",
        typeof(ysfit), "y" )( xs, ysfit ) );

    // Setting range and label for xaxis
    gg + xaxisRange( 0, 8 ) + xaxisLabel( "My xlabel" );
    assertEqual( gg.xaxis.min, 0 );
    // Setting range and label for yaxis
    gg + yaxisRange( 0, 2.0 ) + yaxisLabel( "My ylabel" );
    assertEqual( gg.yaxis.max, 2.0 );
    assertEqual( gg.yaxis.label, "My ylabel" );

    // Change Margins
    gg + Margins( 60, 60, 40, 30 );

    // Saving on a 500x300 pixel surface
    gg.save( "axes.svg", 500, 300 );
}
